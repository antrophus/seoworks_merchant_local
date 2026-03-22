import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../home/home_screen.dart';
import '../inventory/inventory_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(itemStatusCountsProvider);

    return countsAsync.when(
      data: (counts) {
        if (counts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.dashboard_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  '데이터가 없습니다',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  '설정 > 데이터 임포트에서 백업 데이터를 가져오세요',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // 활성 재고 상태들
        final activeStatuses = [
          'ORDER_PLACED',
          'OFFICE_STOCK',
          'OUTGOING',
          'IN_INSPECTION',
          'LISTED',
          'DEFECT_FOR_SALE',
          'DEFECT_HELD',
          'RETURNING',
          'REPAIRING',
        ];
        final totalActive =
            activeStatuses.fold<int>(0, (sum, s) => sum + (counts[s] ?? 0));
        final totalAll = counts.values.fold<int>(0, (sum, v) => sum + v);

        void goToInventory(String? status) {
          ref.read(inventoryFilterProvider.notifier).state = status;
          ref.read(homeTabProvider.notifier).state = 1;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 전체 요약 카드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryItem(
                        label: '전체 아이템',
                        count: totalAll,
                        color: Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _SummaryItem(
                        label: '활성 재고',
                        count: totalActive,
                        color: Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _SummaryItem(
                        label: '정산 완료',
                        count: (counts['SETTLED'] ?? 0) +
                            (counts['DEFECT_SETTLED'] ?? 0),
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 상태별 카드 그리드
            Text(
              '상태별 재고 현황',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: [
                _StatusCard('주문완료', counts['ORDER_PLACED'] ?? 0,
                    Icons.shopping_cart, Colors.orange,
                    onTap: () => goToInventory('ORDER_PLACED')),
                _StatusCard('사무실재고', counts['OFFICE_STOCK'] ?? 0,
                    Icons.warehouse, Colors.blue,
                    onTap: () => goToInventory('OFFICE_STOCK')),
                _StatusCard('발송중', counts['OUTGOING'] ?? 0,
                    Icons.local_shipping, Colors.indigo,
                    onTap: () => goToInventory('OUTGOING')),
                _StatusCard('검수중', counts['IN_INSPECTION'] ?? 0,
                    Icons.fact_check, Colors.purple,
                    onTap: () => goToInventory('IN_INSPECTION')),
                _StatusCard(
                    '리스팅', counts['LISTED'] ?? 0, Icons.sell, Colors.teal,
                    onTap: () => goToInventory('LISTED')),
                _StatusCard('판매완료', counts['SOLD'] ?? 0, Icons.check_circle,
                    Colors.green,
                    onTap: () => goToInventory('SOLD')),
                _StatusCard(
                    '불량판매',
                    (counts['DEFECT_FOR_SALE'] ?? 0) +
                        (counts['DEFECT_SOLD'] ?? 0),
                    Icons.warning,
                    Colors.amber,
                    onTap: () => goToInventory('DEFECT_FOR_SALE')),
                _StatusCard('불량보류', counts['DEFECT_HELD'] ?? 0,
                    Icons.pause_circle, Colors.deepOrange,
                    onTap: () => goToInventory('DEFECT_HELD')),
                _StatusCard('반송중', counts['RETURNING'] ?? 0,
                    Icons.keyboard_return, Colors.red,
                    onTap: () => goToInventory('RETURNING')),
                _StatusCard(
                    '수선중', counts['REPAIRING'] ?? 0, Icons.build, Colors.brown,
                    onTap: () => goToInventory('REPAIRING')),
                _StatusCard(
                    '정산완료',
                    (counts['SETTLED'] ?? 0) + (counts['DEFECT_SETTLED'] ?? 0),
                    Icons.payments,
                    Colors.grey,
                    onTap: () => goToInventory('SETTLED')),
                _StatusCard(
                    '기타',
                    (counts['ORDER_CANCELLED'] ?? 0) +
                        (counts['SUPPLIER_RETURN'] ?? 0) +
                        (counts['DISPOSED'] ?? 0) +
                        (counts['SAMPLE'] ?? 0),
                    Icons.more_horiz,
                    Colors.blueGrey,
                    onTap: () => goToInventory(null)),
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

class _SummaryItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatusCard(this.label, this.count, this.icon, this.color,
      {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: count > 0 ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$count',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: count > 0 ? color : Colors.grey,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
