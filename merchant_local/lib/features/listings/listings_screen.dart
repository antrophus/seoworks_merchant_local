import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';

/// 리스팅 상태 필터
final listingFilterProvider = StateProvider<String?>((ref) => null);

class ListingsScreen extends ConsumerWidget {
  const ListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(listingFilterProvider);
    final listingsAsync = filter == null
        ? ref.watch(poizonListingsProvider)
        : ref.watch(listingsFilteredProvider(filter));

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
                    ref.read(listingFilterProvider.notifier).state = null,
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '판매중',
                selected: filter == 'active',
                onTap: () =>
                    ref.read(listingFilterProvider.notifier).state = 'active',
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '판매완료',
                selected: filter == 'sold',
                onTap: () =>
                    ref.read(listingFilterProvider.notifier).state = 'sold',
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '취소됨',
                selected: filter == 'cancelled',
                onTap: () => ref.read(listingFilterProvider.notifier).state =
                    'cancelled',
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 리스팅 목록
        Expanded(
          child: listingsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sell_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '리스팅이 없습니다',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'POIZON API 연동 후 리스팅 데이터가 표시됩니다',
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
                  return _ListingTile(listing: item);
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
final listingsFilteredProvider =
    StreamProvider.family<List<dynamic>, String>((ref, status) {
  return ref.watch(listingDaoProvider).watchByStatus(status);
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

class _ListingTile extends StatelessWidget {
  final dynamic listing;
  const _ListingTile({required this.listing});

  @override
  Widget build(BuildContext context) {
    final priceStr = NumberFormat('#,###').format(listing.price);
    final statusLabel = switch (listing.status as String) {
      'active' => '판매중',
      'sold' => '판매완료',
      'cancelled' => '취소됨',
      _ => listing.status,
    };
    final statusColor = switch (listing.status as String) {
      'active' => Colors.green,
      'sold' => Colors.blue,
      'cancelled' => Colors.grey,
      _ => Colors.grey,
    };

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.15),
        child: Icon(Icons.sell, color: statusColor, size: 20),
      ),
      title: Text('SKU: ${listing.skuId}'),
      subtitle: Text(
        '$priceStr ${listing.currency}  ·  ${listing.quantity}개  ·  ${listing.listingType}',
      ),
      trailing: Chip(
        label: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12)),
        backgroundColor: statusColor.withValues(alpha: 0.1),
        side: BorderSide.none,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
