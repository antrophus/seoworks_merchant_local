import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

final _wonFormat = NumberFormat('#,###');
final _dateFmt = DateFormat('yyyy-MM-dd');

// ══════════════════════════════════════════════════
// 데이터 모델
// ══════════════════════════════════════════════════

class _PurchaseItem {
  final String itemId;
  final String sku;
  final String sizeKr;
  final String modelName;
  final String modelCode;
  final String currentStatus;
  final int? purchasePrice;
  final String? purchaseDate;
  final String paymentMethod;
  final bool hasReturn;
  final bool isSold;

  const _PurchaseItem({
    required this.itemId,
    required this.sku,
    required this.sizeKr,
    required this.modelName,
    required this.modelCode,
    required this.currentStatus,
    this.purchasePrice,
    this.purchaseDate,
    required this.paymentMethod,
    required this.hasReturn,
    required this.isSold,
  });
}

class _PurchaseGroup {
  final String date;
  final String sourceName;
  final List<_PurchaseItem> items;

  const _PurchaseGroup({
    required this.date,
    required this.sourceName,
    required this.items,
  });

  int get returnCount => items.where((i) => i.hasReturn).length;
  int get returnAmount => items
      .where((i) => i.hasReturn)
      .fold(0, (s, i) => s + (i.purchasePrice ?? 0));
  // 반품 제외 실구매액
  int get totalPrice => items
      .where((i) => !i.hasReturn)
      .fold(0, (s, i) => s + (i.purchasePrice ?? 0));
}

// ══════════════════════════════════════════════════
// Providers
// ══════════════════════════════════════════════════

final _purchaseDateFromProvider = StateProvider<String?>((ref) => null);
final _purchaseDateToProvider = StateProvider<String?>((ref) => null);
final _purchaseLabelProvider = StateProvider<String>((ref) => '전체');

// StreamProvider: customSelect.watch()가 readsFrom 테이블(purchases 포함) 변경 시
// 자동으로 emit → 구입가격/구매처 수정이 즉시 화면에 반영됨
// FutureProvider + ref.watch(itemsProvider) 방식은 purchases 테이블 변경을 감지 불가
final _purchasesProvider = StreamProvider<List<_PurchaseGroup>>((ref) {
  final db = ref.watch(databaseProvider);
  final dateFrom = ref.watch(_purchaseDateFromProvider);
  final dateTo = ref.watch(_purchaseDateToProvider);

  var where = '';
  final vars = <Variable>[];
  if (dateFrom != null) {
    where += ' AND COALESCE(p.purchase_date, p.created_at) >= ?';
    vars.add(Variable.withString(dateFrom));
  }
  if (dateTo != null) {
    where += ' AND COALESCE(p.purchase_date, p.created_at) <= ?';
    vars.add(Variable.withString(dateTo));
  }

  return db.customSelect(
    '''
    SELECT
      p.id,
      i.id AS item_id,
      i.sku,
      i.size_kr,
      i.current_status,
      pr.model_name,
      pr.model_code,
      p.purchase_price,
      p.purchase_date,
      p.payment_method,
      COALESCE(s.name, '구매처 미상') AS source_name,
      CASE WHEN EXISTS (SELECT 1 FROM supplier_returns sr WHERE sr.item_id = i.id)
                OR i.current_status IN ('RETURNING','SUPPLIER_RETURN','CANCEL_RETURNING')
           THEN 1 ELSE 0 END AS has_return,
      CASE WHEN i.current_status IN ('SOLD','SETTLED','DEFECT_SOLD','DEFECT_SETTLED')
           THEN 1 ELSE 0 END AS is_sold
    FROM purchases p
    JOIN items i ON i.id = p.item_id
    JOIN products pr ON pr.id = i.product_id
    LEFT JOIN sources s ON s.id = p.source_id
    WHERE 1=1
    $where
    ORDER BY COALESCE(p.purchase_date, p.created_at) DESC
    ''',
    variables: vars,
    readsFrom: {
      db.purchases,
      db.items,
      db.products,
      db.sources,
      db.supplierReturns,
    },
  ).watch().map((results) {
    // 날짜+구매처로 그룹화
    final groupMap = <String, _PurchaseGroup>{};
    for (final r in results) {
      final date = r.readNullable<String>('purchase_date') ?? '날짜미상';
      final source = r.read<String>('source_name');
      final key = '$date|$source';

      final item = _PurchaseItem(
        itemId: r.read<String>('item_id'),
        sku: r.read<String>('sku'),
        sizeKr: r.read<String>('size_kr'),
        modelName: r.read<String>('model_name'),
        modelCode: r.read<String>('model_code'),
        currentStatus: r.read<String>('current_status'),
        purchasePrice: r.readNullable<int>('purchase_price'),
        purchaseDate: r.readNullable<String>('purchase_date'),
        paymentMethod: r.read<String>('payment_method'),
        hasReturn: r.read<int>('has_return') == 1,
        isSold: r.read<int>('is_sold') == 1,
      );

      if (groupMap.containsKey(key)) {
        final existing = groupMap[key]!;
        groupMap[key] = _PurchaseGroup(
          date: existing.date,
          sourceName: existing.sourceName,
          items: [...existing.items, item],
        );
      } else {
        groupMap[key] = _PurchaseGroup(
          date: date,
          sourceName: source,
          items: [item],
        );
      }
    }
    return groupMap.values.toList();
  });
});

// ══════════════════════════════════════════════════
// Screen
// ══════════════════════════════════════════════════

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  final Set<String> _expandedGroups = {};

  String _key(_PurchaseGroup g) => '${g.date}|${g.sourceName}';
  bool _isExpanded(_PurchaseGroup g) => _expandedGroups.contains(_key(g));
  void _toggle(_PurchaseGroup g) {
    setState(() {
      final k = _key(g);
      if (_expandedGroups.contains(k)) {
        _expandedGroups.remove(k);
      } else {
        _expandedGroups.add(k);
      }
    });
  }

  Map<String, int> _calcStats(List<_PurchaseItem> items) {
    int purchaseCount = 0, purchaseAmount = 0;
    int returnCount = 0, returnAmount = 0;
    int saleCount = 0;
    for (final i in items) {
      purchaseCount++;
      if (i.hasReturn) {
        returnCount++;
        returnAmount += i.purchasePrice ?? 0;
      } else {
        purchaseAmount += i.purchasePrice ?? 0;
      }
      if (i.isSold) saleCount++;
    }
    return {
      'purchaseCount': purchaseCount,
      'purchaseAmount': purchaseAmount,
      'returnCount': returnCount,
      'returnAmount': returnAmount,
      'saleCount': saleCount,
    };
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_purchasesProvider);
    final label = ref.watch(_purchaseLabelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('구매 내역'),
        actions: [
          PopupMenuButton<String>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 4),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const Icon(Icons.arrow_drop_down, size: 16),
              ],
            ),
            onSelected: (v) async {
              final now = DateTime.now();
              if (v == 'all') {
                ref.read(_purchaseDateFromProvider.notifier).state = null;
                ref.read(_purchaseDateToProvider.notifier).state = null;
                ref.read(_purchaseLabelProvider.notifier).state = '전체';
              } else if (v == 'thismonth') {
                ref.read(_purchaseDateFromProvider.notifier).state =
                    _dateFmt.format(DateTime(now.year, now.month, 1));
                ref.read(_purchaseDateToProvider.notifier).state =
                    _dateFmt.format(now);
                ref.read(_purchaseLabelProvider.notifier).state = '이번달';
              } else if (v == 'lastmonth') {
                final from = DateTime(now.year, now.month - 1, 1);
                final to = DateTime(now.year, now.month, 0);
                ref.read(_purchaseDateFromProvider.notifier).state =
                    _dateFmt.format(from);
                ref.read(_purchaseDateToProvider.notifier).state =
                    _dateFmt.format(to);
                ref.read(_purchaseLabelProvider.notifier).state = '지난달';
              } else if (v == 'custom') {
                final start = await showDatePicker(
                  context: context,
                  initialDate: DateTime(now.year, now.month, 1),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (start == null) return;
                if (!context.mounted) return;
                final end = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: start,
                  lastDate: DateTime(2030),
                );
                if (end != null) {
                  ref.read(_purchaseDateFromProvider.notifier).state =
                      _dateFmt.format(start);
                  ref.read(_purchaseDateToProvider.notifier).state =
                      _dateFmt.format(end);
                  ref.read(_purchaseLabelProvider.notifier).state =
                      '${_dateFmt.format(start).substring(5)} ~ ${_dateFmt.format(end).substring(5)}';
                }
              } else {
                // year
                final year = int.parse(v);
                final isCurrentYear = year == now.year;
                ref.read(_purchaseDateFromProvider.notifier).state =
                    '$year-01-01';
                ref.read(_purchaseDateToProvider.notifier).state =
                    isCurrentYear ? _dateFmt.format(now) : '$year-12-31';
                ref.read(_purchaseLabelProvider.notifier).state = '$year년';
              }
            },
            itemBuilder: (_) {
              final now = DateTime.now();
              return [
                PopupMenuItem(value: 'all', child: Text('전체', style: TextStyle(fontWeight: label == '전체' ? FontWeight.bold : FontWeight.normal))),
                PopupMenuItem(value: 'thismonth', child: Text('이번달', style: TextStyle(fontWeight: label == '이번달' ? FontWeight.bold : FontWeight.normal))),
                PopupMenuItem(value: 'lastmonth', child: Text('지난달', style: TextStyle(fontWeight: label == '지난달' ? FontWeight.bold : FontWeight.normal))),
                PopupMenuItem(value: now.year.toString(), child: Text('${now.year}년', style: TextStyle(fontWeight: label == '${now.year}년' ? FontWeight.bold : FontWeight.normal))),
                PopupMenuItem(value: (now.year - 1).toString(), child: Text('${now.year - 1}년', style: TextStyle(fontWeight: label == '${now.year - 1}년' ? FontWeight.bold : FontWeight.normal))),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'custom',
                  child: Row(children: [Icon(Icons.date_range, size: 16), SizedBox(width: 8), Text('기간 선택')]),
                ),
              ];
            },
          ),
        ],
      ),
      body: async.when(
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Text('구매 내역이 없습니다',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textTertiary)),
            );
          }

          final allItems = groups.expand((g) => g.items).toList();
          final stats = _calcStats(allItems);

          return CustomScrollView(
            slivers: [
              // ── 상단 통계 요약 (고정) ──
              SliverToBoxAdapter(child: _StatsHeader(stats: stats)),

              // ── 그룹별 sticky 헤더 + 아이템 목록 ──
              for (final group in groups) ...[
                SliverPersistentHeader(
                  pinned: _isExpanded(group),
                  delegate: _GroupHeaderDelegate(
                    group: group,
                    isExpanded: _isExpanded(group),
                    onToggle: () => _toggle(group),
                  ),
                ),
                if (_isExpanded(group))
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        if (i == 0) {
                          return const Divider(
                              height: 1, indent: AppSpacing.md);
                        }
                        return _PurchaseItemRow(
                            item: group.items[i - 1]);
                      },
                      childCount: group.items.length + 1,
                    ),
                  ),
              ],
              const SliverPadding(
                  padding: EdgeInsets.only(bottom: 32)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 상단 통계 헤더
// ══════════════════════════════════════════════════

class _StatsHeader extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsHeader({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(30),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          _StatPill('구입', stats['purchaseCount']!, '건',
              AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          _StatPill('구매액', stats['purchaseAmount']!, '원',
              AppColors.primary, isAmount: true),
          const SizedBox(width: AppSpacing.sm),
          _StatPill('반품', stats['returnCount']!, '건',
              AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          _StatPill('반품액', stats['returnAmount']!, '원',
              AppColors.error, isAmount: true),
          const SizedBox(width: AppSpacing.sm),
          _StatPill('판매', stats['saleCount']!, '건',
              AppColors.success),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int value;
  final String unit;
  final Color color;
  final bool isAmount;

  const _StatPill(this.label, this.value, this.unit, this.color,
      {this.isAmount = false});

  @override
  Widget build(BuildContext context) {
    final displayValue = isAmount
        ? _wonFormat.format(value)
        : value.toString();

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$displayValue$unit',
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 그룹 Sticky 헤더 Delegate
// ══════════════════════════════════════════════════

class _GroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  final _PurchaseGroup group;
  final bool isExpanded;
  final VoidCallback onToggle;

  static const double _h = 70.0;

  const _GroupHeaderDelegate({
    required this.group,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  double get maxExtent => _h;
  @override
  double get minExtent => _h;
  @override
  bool shouldRebuild(_GroupHeaderDelegate old) =>
      old.isExpanded != isExpanded ||
      old.group.items.length != group.items.length ||
      old.group.totalPrice != group.totalPrice;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final hasReturn = group.returnCount > 0;
    final cardColor = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    // SizedBox.expand() 로 child가 SliverPersistentHeader가 제공하는
    // 전체 높이를 채우게 하여 childExtent == maxExtent 보장 → paintExtent == layoutExtent
    return SizedBox.expand(
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 4, AppSpacing.md, 4),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withAlpha(isExpanded ? 60 : 30),
              ),
              boxShadow: overlapsContent
                  ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 10, AppSpacing.sm, 10),
                child: Row(
                  children: [
                    // 날짜 + 구매처
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            group.date,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            group.sourceName,
                            style: AppTheme.dataStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    // 건수 + 금액 (반품 포함 시 -X건 / -XX원 추가)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text('${group.items.length}건',
                                style: AppTheme.dataStyle(
                                    fontSize: 11, fontWeight: FontWeight.w500)),
                            if (hasReturn) ...[
                              const SizedBox(width: 4),
                              Text('-${group.returnCount}건',
                                  style: AppTheme.dataStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.error)),
                            ],
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              '${_wonFormat.format(group.totalPrice)}원',
                              style: AppTheme.dataStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary),
                            ),
                            if (hasReturn) ...[
                              const SizedBox(width: 4),
                              Text(
                                '-${_wonFormat.format(group.returnAmount)}원',
                                style: AppTheme.dataStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.error),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),        // InkWell
            ),        // Material
          ),          // Container (inner card)
        ),            // Padding (outer)
      ),              // Container (outer bg)
    );               // SizedBox
  }
}

// ══════════════════════════════════════════════════
// 개별 구매 아이템 행
// ══════════════════════════════════════════════════

class _PurchaseItemRow extends StatelessWidget {
  final _PurchaseItem item;
  const _PurchaseItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/item/${item.itemId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 10),
        child: Row(
          children: [
            // 사이즈
            SizedBox(
              width: 32,
              child: Text(
                item.sizeKr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: item.hasReturn ? AppColors.textTertiary : null,
                    ),
              ),
            ),
            // 모델명
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.modelName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: item.hasReturn
                                    ? AppColors.textTertiary
                                    : null,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.hasReturn)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.undo,
                              size: 12, color: AppColors.error),
                        ),
                      if (item.isSold)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.check_circle,
                              size: 12, color: AppColors.success),
                        ),
                    ],
                  ),
                  Text(
                    item.modelCode,
                    style: AppTheme.dataStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            // 구매가 — 반품 시 취소선
            if (item.purchasePrice != null)
              Text(
                '${_wonFormat.format(item.purchasePrice)}원',
                style: AppTheme.dataStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: item.hasReturn ? AppColors.textTertiary : null,
                ).copyWith(
                  decoration: item.hasReturn
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor: AppColors.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

