import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/database/daos/sale_dao.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

final _wonFormat = NumberFormat('#,###');

// ── Providers ──

final _platformFilterProvider = StateProvider<String?>((ref) => null);
final _dateFromProvider = StateProvider<String?>((ref) => null);
final _dateToProvider = StateProvider<String?>((ref) => null);

final _settledSalesProvider = FutureProvider<List<SaleWithItem>>((ref) {
  final dao = ref.watch(saleDaoProvider);
  final platform = ref.watch(_platformFilterProvider);
  final dateFrom = ref.watch(_dateFromProvider);
  final dateTo = ref.watch(_dateToProvider);
  return dao.getSettledSales(
    platform: platform,
    dateFrom: dateFrom,
    dateTo: dateTo,
  );
});

final _salesSummaryProvider = FutureProvider<Map<String, num>>((ref) {
  final dao = ref.watch(saleDaoProvider);
  final platform = ref.watch(_platformFilterProvider);
  final dateFrom = ref.watch(_dateFromProvider);
  final dateTo = ref.watch(_dateToProvider);
  return dao.getSalesSummary(
    platform: platform,
    dateFrom: dateFrom,
    dateTo: dateTo,
  );
});

/// 브랜드-모델명 그룹 데이터
class _ModelGroup {
  final String brandName;
  final String modelName;
  final String modelCode;
  final List<SaleWithItem> items;

  _ModelGroup({
    required this.brandName,
    required this.modelName,
    required this.modelCode,
    required this.items,
  });

  int get totalProfit {
    var sum = 0;
    for (final s in items) {
      final settlement = s.sale.settlementAmount ?? 0;
      sum += settlement;
    }
    return sum;
  }

  String? get earliestSettledAt {
    String? earliest;
    for (final s in items) {
      final d = s.sale.settledAt ?? s.sale.saleDate;
      if (d != null && (earliest == null || d.compareTo(earliest) < 0)) {
        earliest = d;
      }
    }
    return earliest;
  }
}

List<_ModelGroup> _groupBySales(List<SaleWithItem> sales) {
  final map = <String, _ModelGroup>{};
  for (final s in sales) {
    final key = '${s.product.brandId ?? ''}|${s.product.modelCode}';
    if (map.containsKey(key)) {
      map[key]!.items.add(s);
    } else {
      map[key] = _ModelGroup(
        brandName: '', // filled below
        modelName: s.product.modelName,
        modelCode: s.product.modelCode,
        items: [s],
      );
    }
  }
  // brandName은 product 테이블에 없으므로 첫 아이템 기준으로 빈 값 유지
  // → 대신 modelName만 사용
  return map.values.toList();
}

// ── Screen ──

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(_salesSummaryProvider);
    final listAsync = ref.watch(_settledSalesProvider);
    final platformFilter = ref.watch(_platformFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('판매 내역'),
      ),
      body: Column(
        children: [
          // ── 필터 영역 ──
          Container(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withAlpha(30),
                ),
              ),
            ),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: '전체',
                        selected: platformFilter == null,
                        onTap: () => ref
                            .read(_platformFilterProvider.notifier)
                            .state = null,
                      ),
                      for (final p in [
                        'POIZON',
                        'KREAM',
                        'SOLDOUT',
                        'DIRECT',
                        'OTHER'
                      ])
                        _FilterChip(
                          label: p,
                          selected: platformFilter == p,
                          onTap: () => ref
                              .read(_platformFilterProvider.notifier)
                              .state = p,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _DateFilterRow(),
              ],
            ),
          ),

          // ── 통계 카드 ──
          summaryAsync.when(
            data: (s) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  _StatCard(
                      label: '판매',
                      value: '${_wonFormat.format(s['totalSell'])}원',
                      color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  _StatCard(
                      label: '정산',
                      value: '${_wonFormat.format(s['totalSettlement'])}원',
                      color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  _StatCard(
                      label: '이익',
                      value: '${_wonFormat.format(s['totalProfit'])}원',
                      color: (s['totalProfit'] as num) >= 0
                          ? AppColors.success
                          : AppColors.error),
                  const SizedBox(width: AppSpacing.sm),
                  _StatCard(
                      label: '마진',
                      value:
                          '${(s['marginRate'] as num).toStringAsFixed(1)}%',
                      color: AppColors.accent),
                ],
              ),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SizedBox(height: 60),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text('오류: $e'),
            ),
          ),

          // ── 그룹핑 목록 ──
          Expanded(
            child: listAsync.when(
              data: (sales) {
                if (sales.isEmpty) {
                  return Center(
                    child: Text(
                      '정산 완료 내역이 없습니다',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textTertiary),
                    ),
                  );
                }
                final groups = _groupBySales(sales);
                // 그룹 내 가장 오래된 정산일 기준 정렬
                groups.sort((a, b) =>
                    (a.earliestSettledAt ?? '')
                        .compareTo(b.earliestSettledAt ?? ''));

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: groups.length,
                  itemBuilder: (context, i) =>
                      _ModelGroupTile(group: groups[i]),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 위젯: 모델 그룹 타일 ──
class _ModelGroupTile extends StatelessWidget {
  final _ModelGroup group;

  const _ModelGroupTile({required this.group});

  @override
  Widget build(BuildContext context) {
    final items = group.items;
    final totalSettlement = items.fold<int>(
        0, (sum, s) => sum + (s.sale.settlementAmount ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(30),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
          title: Text(
            group.modelName,
            style: Theme.of(context).textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Text(
                group.modelCode,
                style: AppTheme.dataStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${items.length}건',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                '${_wonFormat.format(totalSettlement)}원',
                style: AppTheme.dataStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          children: [
            for (final s in items) _SaleItemRow(data: s),
          ],
        ),
      ),
    );
  }
}

// ── 위젯: 그룹 내 개별 아이템 ──
class _SaleItemRow extends StatelessWidget {
  final SaleWithItem data;

  const _SaleItemRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final sale = data.sale;
    final item = data.item;
    final settledDate =
        sale.settledAt?.substring(0, 10) ?? sale.saleDate ?? '-';

    return InkWell(
      onTap: () => context.push('/item/${item.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            // 사이즈
            SizedBox(
              width: 36,
              child: Text(
                item.sizeKr.isEmpty ? '-' : item.sizeKr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            // 플랫폼
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                sale.platform,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontSize: 9,
                    ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // 판매가
            Expanded(
              child: Text(
                sale.sellPrice != null
                    ? '${_wonFormat.format(sale.sellPrice)}원'
                    : '-',
                style: AppTheme.dataStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // 정산금
            Text(
              sale.settlementAmount != null
                  ? '${_wonFormat.format(sale.settlementAmount)}원'
                  : '-',
              style: AppTheme.dataStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // 정산일
            Text(
              settledDate,
              style: AppTheme.dataStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 위젯: 필터 칩 ──
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

// ── 위젯: 날짜 필터 ──
class _DateFilterRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFrom = ref.watch(_dateFromProvider);
    final dateTo = ref.watch(_dateToProvider);

    Future<void> pickDate(bool isFrom) async {
      final initial = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (picked != null) {
        final formatted = DateFormat('yyyy-MM-dd').format(picked);
        if (isFrom) {
          ref.read(_dateFromProvider.notifier).state = formatted;
        } else {
          ref.read(_dateToProvider.notifier).state = formatted;
        }
      }
    }

    return Row(
      children: [
        _PresetButton(
          label: '이번달',
          onTap: () {
            final now = DateTime.now();
            ref.read(_dateFromProvider.notifier).state =
                DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month));
            ref.read(_dateToProvider.notifier).state =
                DateFormat('yyyy-MM-dd').format(now);
          },
        ),
        _PresetButton(
          label: '지난달',
          onTap: () {
            final now = DateTime.now();
            final from = DateTime(now.year, now.month - 1);
            final to = DateTime(now.year, now.month, 0);
            ref.read(_dateFromProvider.notifier).state =
                DateFormat('yyyy-MM-dd').format(from);
            ref.read(_dateToProvider.notifier).state =
                DateFormat('yyyy-MM-dd').format(to);
          },
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: InkWell(
            onTap: () => pickDate(true),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs + 2),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                dateFrom ?? '시작일',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: dateFrom != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('~', style: TextStyle(color: AppColors.textTertiary)),
        ),
        Expanded(
          child: InkWell(
            onTap: () => pickDate(false),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs + 2),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                dateTo ?? '종료일',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: dateTo != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
              ),
            ),
          ),
        ),
        if (dateFrom != null || dateTo != null)
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () {
              ref.read(_dateFromProvider.notifier).state = null;
              ref.read(_dateToProvider.notifier).state = null;
            },
          ),
      ],
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs + 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child:
              Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
      ),
    );
  }
}

// ── 위젯: 통계 카드 ──
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withAlpha(30),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTheme.dataStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
