import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';

/// 주문 상태 필터
final orderFilterProvider = StateProvider<String?>((ref) => null);

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(orderFilterProvider);
    final ordersAsync = filter == null
        ? ref.watch(poizonOrdersProvider)
        : ref.watch(ordersFilteredProvider(filter));

    return Column(
      children: [
        // 상태 필터 칩
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _FilterChip(
                label: '전체',
                selected: filter == null,
                onTap: () =>
                    ref.read(orderFilterProvider.notifier).state = null,
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '대기',
                selected: filter == 'pending',
                onTap: () =>
                    ref.read(orderFilterProvider.notifier).state = 'pending',
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '확인됨',
                selected: filter == 'confirmed',
                onTap: () =>
                    ref.read(orderFilterProvider.notifier).state = 'confirmed',
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '발송됨',
                selected: filter == 'shipped',
                onTap: () =>
                    ref.read(orderFilterProvider.notifier).state = 'shipped',
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '완료',
                selected: filter == 'completed',
                onTap: () =>
                    ref.read(orderFilterProvider.notifier).state = 'completed',
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 주문 목록
        Expanded(
          child: ordersAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '주문이 없습니다',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'POIZON API 연동 후 주문 데이터가 표시됩니다',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _OrderTile(order: item);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
          ),
        ),
      ],
    );
  }
}

/// 상태별 필터 Provider
final ordersFilteredProvider =
    StreamProvider.family<List<dynamic>, String>((ref, status) {
  return ref.watch(orderDaoProvider).watchByStatus(status);
});

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
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final dynamic order;
  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final priceStr = NumberFormat('#,###').format(order.salePrice);
    final dateStr = DateFormat('MM/dd HH:mm').format(order.orderedAt);
    final statusLabel = switch (order.status as String) {
      'pending' => '대기',
      'confirmed' => '확인됨',
      'shipped' => '발송됨',
      'completed' => '완료',
      _ => order.status,
    };
    final statusColor = switch (order.status as String) {
      'pending' => Colors.orange,
      'confirmed' => Colors.blue,
      'shipped' => Colors.indigo,
      'completed' => Colors.green,
      _ => Colors.grey,
    };

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.15),
        child: Icon(Icons.shopping_bag, color: statusColor, size: 20),
      ),
      title: Text('주문 ${order.orderId}'),
      subtitle: Text('SKU: ${order.skuId}  ·  $priceStr원  ·  $dateStr'),
      trailing: Chip(
        label: Text(statusLabel,
            style: TextStyle(color: statusColor, fontSize: 12)),
        backgroundColor: statusColor.withValues(alpha: 0.1),
        side: BorderSide.none,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
