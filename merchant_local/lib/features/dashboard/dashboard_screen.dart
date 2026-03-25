import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/providers.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../home/home_screen.dart';
import '../inventory/inventory_providers.dart';

final _wonFormat = NumberFormat('#,###');

String _statusLabel(String status) => switch (status) {
      'ORDER_PLACED' => '입고대기',
      'OFFICE_STOCK' => '미등록재고',
      'LISTED' => '판매중',
      'POIZON_STORAGE' => '포이즌보관',
      'SOLD' => '판매완료',
      'OUTGOING' => '발송완료',
      'IN_INSPECTION' => '검수중',
      'SETTLED' => '정산완료',
      'DEFECT_SETTLED' => '하자정산',
      'DEFECT_FOR_SALE' => '하자판매',
      'DEFECT_SOLD' => '하자판매완료',
      'DEFECT_HELD' => '하자보류',
      'RETURNING' => '반송중',
      'CANCEL_RETURNING' => '취소반송',
      'REPAIRING' => '수선중',
      'SUPPLIER_RETURN' => '반품완료',
      'ORDER_CANCELLED' => '주문취소',
      'DISPOSED' => '폐기',
      'SAMPLE' => '샘플',
      _ => status,
    };

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(itemStatusCountsProvider);

    return countsAsync.when(
      data: (counts) {
        if (counts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: const Icon(Icons.dashboard_outlined,
                        size: 40, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '데이터가 없습니다',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '설정 > 데이터 임포트에서 백업 데이터를 가져오세요',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final totalSettled =
            (counts['SETTLED'] ?? 0) + (counts['DEFECT_SETTLED'] ?? 0);
        final totalShipping =
            (counts['OUTGOING'] ?? 0) + (counts['IN_INSPECTION'] ?? 0);
        final totalDefect = (counts['DEFECT_FOR_SALE'] ?? 0) +
            (counts['DEFECT_HELD'] ?? 0) +
            (counts['DEFECT_SOLD'] ?? 0);
        final totalReturning = (counts['RETURNING'] ?? 0) +
            (counts['CANCEL_RETURNING'] ?? 0) +
            (counts['REPAIRING'] ?? 0);

        void goToInventory(String? status) {
          ref.read(inventoryFilterProvider.notifier).state = status;
          ref.read(homeTabProvider.notifier).state = 1;
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // ── 긴급 알림 ──
            _UrgentAlertBanner(onTap: () {
              ref.read(inventorySortAscProvider.notifier).state = true;
              goToInventory('IN_INSPECTION');
            }),
            // ── KPI 카드 6개 (2x3 그리드) ──
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.1,
              children: [
                _KpiCard(
                  label: '미등록 재고',
                  count: (counts['ORDER_PLACED'] ?? 0) +
                      (counts['OFFICE_STOCK'] ?? 0),
                  icon: Icons.warehouse_outlined,
                  color: AppColors.statusOfficeStock,
                  onTap: () => goToInventory('ORDER_PLACED,OFFICE_STOCK'),
                ),
                _KpiCard(
                  label: '발송/검수',
                  count: totalShipping,
                  icon: Icons.local_shipping_outlined,
                  color: AppColors.statusOutgoing,
                  onTap: () => goToInventory('OUTGOING,IN_INSPECTION'),
                ),
                _KpiCard(
                  label: '판매중',
                  count: (counts['LISTED'] ?? 0) +
                      (counts['POIZON_STORAGE'] ?? 0),
                  icon: Icons.sell_outlined,
                  color: AppColors.statusListed,
                  onTap: () => goToInventory('LISTED,POIZON_STORAGE'),
                ),
                _KpiCard(
                  label: '하자',
                  count: totalDefect,
                  icon: Icons.warning_amber_outlined,
                  color: AppColors.statusDefectSale,
                  onTap: () =>
                      goToInventory('DEFECT_FOR_SALE,DEFECT_HELD,DEFECT_SOLD'),
                ),
                _KpiCard(
                  label: '정산',
                  count: totalSettled,
                  icon: Icons.payments_outlined,
                  color: AppColors.statusSettled,
                  onTap: () => goToInventory('SETTLED,DEFECT_SETTLED'),
                ),
                _KpiCard(
                  label: '반송/수선',
                  count: totalReturning,
                  icon: Icons.keyboard_return,
                  color: AppColors.statusReturning,
                  onTap: () =>
                      goToInventory('RETURNING,CANCEL_RETURNING,REPAIRING'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── 자산 개요 ──
            _AssetOverviewSection(),
            const SizedBox(height: AppSpacing.lg),

            // ── 브랜드 Top 6 ──
            _BrandBarChart(),
            const SizedBox(height: AppSpacing.lg),

            // ── 상태별 재고 현황 ──
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                '상태별 재고 현황',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            GridView.count(
              crossAxisCount:
                  MediaQuery.of(context).size.width > 600 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 2.0,
              children: [
                _StatusTile(
                  label: '판매중',
                  count: (counts['LISTED'] ?? 0) +
                      (counts['POIZON_STORAGE'] ?? 0),
                  icon: Icons.sell_outlined,
                  status: 'LISTED',
                  onTap: () => goToInventory('LISTED,POIZON_STORAGE'),
                ),
                _StatusTile(
                  label: '미등록',
                  count: (counts['ORDER_PLACED'] ?? 0) +
                      (counts['OFFICE_STOCK'] ?? 0),
                  icon: Icons.warehouse_outlined,
                  status: 'OFFICE_STOCK',
                  onTap: () => goToInventory('ORDER_PLACED,OFFICE_STOCK'),
                ),
                _StatusTile(
                  label: '발송중',
                  count: counts['OUTGOING'] ?? 0,
                  icon: Icons.local_shipping_outlined,
                  status: 'OUTGOING',
                  onTap: () => goToInventory('OUTGOING'),
                ),
                _StatusTile(
                  label: '검수중',
                  count: counts['IN_INSPECTION'] ?? 0,
                  icon: Icons.fact_check_outlined,
                  status: 'IN_INSPECTION',
                  onTap: () => goToInventory('IN_INSPECTION'),
                ),
                _StatusTile(
                  label: '판매완료',
                  count: counts['SOLD'] ?? 0,
                  icon: Icons.check_circle_outline,
                  status: 'SOLD',
                  onTap: () => goToInventory('SOLD'),
                ),
                _StatusTile(
                  label: '불량판매',
                  count: (counts['DEFECT_FOR_SALE'] ?? 0) +
                      (counts['DEFECT_SOLD'] ?? 0),
                  icon: Icons.warning_amber_outlined,
                  status: 'DEFECT_FOR_SALE',
                  onTap: () => goToInventory('DEFECT_FOR_SALE'),
                ),
                _StatusTile(
                  label: '불량보류',
                  count: counts['DEFECT_HELD'] ?? 0,
                  icon: Icons.pause_circle_outline,
                  status: 'DEFECT_HELD',
                  onTap: () => goToInventory('DEFECT_HELD'),
                ),
                _StatusTile(
                  label: '반송중',
                  count: (counts['RETURNING'] ?? 0) +
                      (counts['CANCEL_RETURNING'] ?? 0),
                  icon: Icons.keyboard_return,
                  status: 'RETURNING',
                  onTap: () => goToInventory('RETURNING,CANCEL_RETURNING'),
                ),
                _StatusTile(
                  label: '수선중',
                  count: counts['REPAIRING'] ?? 0,
                  icon: Icons.build_outlined,
                  status: 'REPAIRING',
                  onTap: () => goToInventory('REPAIRING'),
                ),
                _StatusTile(
                  label: '정산완료',
                  count: totalSettled,
                  icon: Icons.payments_outlined,
                  status: 'SETTLED',
                  onTap: () => goToInventory('SETTLED'),
                ),
                _StatusTile(
                  label: '기타',
                  count: (counts['ORDER_CANCELLED'] ?? 0) +
                      (counts['SUPPLIER_RETURN'] ?? 0) +
                      (counts['DISPOSED'] ?? 0) +
                      (counts['SAMPLE'] ?? 0),
                  icon: Icons.more_horiz,
                  status: 'ORDER_CANCELLED',
                  onTap: () => goToInventory(
                      'ORDER_CANCELLED,SUPPLIER_RETURN,DISPOSED,SAMPLE'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── 최근 활동 ──
            _RecentActivitySection(),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
    );
  }
}

// ── KPI 카드 ──
class _KpiCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: count > 0 ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: count > 0
                  ? color.withAlpha(50)
                  : Theme.of(context).colorScheme.outline.withAlpha(30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Text(
                '$count',
                style: AppTheme.dataStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: count > 0 ? color : AppColors.textTertiary,
                ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: count > 0 ? null : AppColors.textTertiary,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 자산 개요 섹션 ──
class _AssetOverviewSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetAsync = ref.watch(assetSummaryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('자산 개요', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton(
              onPressed: () => context.push('/analytics'),
              child: const Text('분석 보기 →'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        assetAsync.when(
          data: (asset) {
            final cost = asset['totalCost'] ?? 0;
            final listed = asset['totalListed'] ?? 0;
            final settlement = asset['totalSettlement'] ?? 0;
            final profit = asset['totalProfit'] ?? 0;

            return Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color:
                      Theme.of(context).colorScheme.outline.withAlpha(50),
                ),
              ),
              child: Column(
                children: [
                  _AssetRow(
                      label: '총 구매원가',
                      value: cost,
                      icon: Icons.shopping_cart_outlined),
                  const Divider(height: AppSpacing.lg),
                  _AssetRow(
                      label: '등록가 합계',
                      value: listed,
                      icon: Icons.sell_outlined),
                  const Divider(height: AppSpacing.lg),
                  _AssetRow(
                      label: '정산금 합계',
                      value: settlement,
                      icon: Icons.account_balance_outlined),
                  const Divider(height: AppSpacing.lg),
                  _AssetRow(
                    label: '예상 이익',
                    value: profit,
                    icon: Icons.trending_up,
                    valueColor:
                        profit >= 0 ? AppColors.success : AppColors.error,
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text('오류: $e'),
        ),
      ],
    );
  }
}

class _AssetRow extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color? valueColor;

  const _AssetRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(
          '${_wonFormat.format(value)}원',
          style: AppTheme.dataStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ── 최근 활동 섹션 ──
class _RecentActivitySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(recentActivityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('최근 활동', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        activityAsync.when(
          data: (logs) {
            if (logs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: Text(
                    '활동 이력이 없습니다',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textTertiary),
                  ),
                ),
              );
            }
            return Column(
              children:
                  logs.map((log) => _ActivityTile(log: log)).toList(),
            );
          },
          loading: () => const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text('오류: $e'),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final StatusLogData log;

  const _ActivityTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final newColor = statusColor(log.newStatus);
    final timeStr = log.changedAt?.substring(0, 16).replaceFirst('T', ' ') ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withAlpha(20),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: newColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (log.oldStatus != null) ...[
                        Text(
                          _statusLabel(log.oldStatus!),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                        ),
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                          child: Icon(Icons.arrow_forward,
                              size: 12, color: AppColors.textTertiary),
                        ),
                      ],
                      Text(
                        _statusLabel(log.newStatus),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: newColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  if (log.note != null && log.note!.isNotEmpty)
                    Text(
                      log.note!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Text(
              timeStr,
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

// ── 상태별 타일 (기존) ──
class _StatusTile extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final String status;
  final VoidCallback? onTap;

  const _StatusTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    final isActive = count > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isActive ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isActive
                  ? color.withAlpha(40)
                  : Theme.of(context).colorScheme.outline.withAlpha(30),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? color : AppColors.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        color: isActive ? color : AppColors.textTertiary,
                        size: 18),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isActive ? null : AppColors.textTertiary,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                '$count',
                style: AppTheme.dataStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isActive ? color : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 긴급 알림 배너 ──
class _UrgentAlertBanner extends ConsumerWidget {
  final VoidCallback onTap;

  const _UrgentAlertBanner({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(overdueInspectionCountProvider);

    return countAsync.when(
      data: (count) {
        if (count == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(15),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.error.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(30),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.schedule,
                          color: AppColors.error, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '검수 지연 경고',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error,
                                ),
                          ),
                          Text(
                            '$count건의 아이템이 12일 이상 검수 대기중',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.error, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ── 브랜드 Top 6 Bar 차트 ──
class _BrandBarChart extends ConsumerWidget {
  static const _barColors = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandsAsync = ref.watch(topBrandsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('브랜드 Top 6', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        brandsAsync.when(
          data: (brands) {
            if (brands.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: Text(
                    '데이터가 없습니다',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textTertiary),
                  ),
                ),
              );
            }
            final maxCount = brands
                .map((b) => (b['count'] as int))
                .reduce((a, b) => a > b ? a : b);

            return Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color:
                      Theme.of(context).colorScheme.outline.withAlpha(50),
                ),
              ),
              child: SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxCount * 1.2,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final brand = brands[group.x];
                          return BarTooltipItem(
                            '${brand['brandName']}\n${brand['count']}건',
                            TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= brands.length) {
                              return const SizedBox.shrink();
                            }
                            final name =
                                brands[idx]['brandName'] as String;
                            final display = name.length > 6
                                ? '${name.substring(0, 6)}..'
                                : name;
                            return Padding(
                              padding:
                                  const EdgeInsets.only(top: AppSpacing.xs),
                              child: Text(
                                display,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: List.generate(brands.length, (i) {
                      final count =
                          (brands[i]['count'] as int).toDouble();
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: count,
                            color: _barColors[i % _barColors.length],
                            width: 24,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            );
          },
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text('오류: $e'),
        ),
      ],
    );
  }
}
