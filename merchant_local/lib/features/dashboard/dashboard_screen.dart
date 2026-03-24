import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../home/home_screen.dart';
import '../inventory/inventory_providers.dart';

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

        final activeStatuses = [
          'ORDER_PLACED',
          'OFFICE_STOCK',
          'OUTGOING',
          'IN_INSPECTION',
          'LISTED',
          'POIZON_STORAGE',
          'DEFECT_FOR_SALE',
          'DEFECT_HELD',
          'RETURNING',
          'CANCEL_RETURNING',
          'REPAIRING',
        ];
        final totalActive =
            activeStatuses.fold<int>(0, (sum, s) => sum + (counts[s] ?? 0));
        final totalAll = counts.values.fold<int>(0, (sum, v) => sum + v);
        final totalSettled =
            (counts['SETTLED'] ?? 0) + (counts['DEFECT_SETTLED'] ?? 0);

        void goToInventory(String? status) {
          ref.read(inventoryFilterProvider.notifier).state = status;
          ref.read(homeTabProvider.notifier).state = 1;
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // ── 요약 카드 3개 ──
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: '전체',
                    count: totalAll,
                    color: AppColors.primary,
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SummaryCard(
                    label: '활성 재고',
                    count: totalActive,
                    color: AppColors.success,
                    icon: Icons.trending_up,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SummaryCard(
                    label: '정산 완료',
                    count: totalSettled,
                    color: AppColors.textTertiary,
                    icon: Icons.payments_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── 섹션 헤더 ──
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                '상태별 재고 현황',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),

            // ── 상태별 카드 그리드 ──
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
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
    );
  }
}

/// 상단 요약 카드 — Flat design, color-blocked left accent
class _SummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(50),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon in colored container
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Count
          Text(
            '$count',
            style: AppTheme.dataStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          // Label
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// 상태별 타일 — Flat touch-first card with left color accent
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
              // Color dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? color : AppColors.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Label + Icon
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: isActive ? color : AppColors.textTertiary,
                        size: 18),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isActive
                                ? null
                                : AppColors.textTertiary,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Count
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
