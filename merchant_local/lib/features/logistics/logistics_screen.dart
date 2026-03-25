import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

final _allShipmentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  final results = await db.customSelect(
    '''SELECT sh.*, i.sku, i.id as item_id, pr.model_name, pr.model_code
       FROM shipments sh
       JOIN items i ON i.id = sh.item_id
       JOIN products pr ON pr.id = i.product_id
       ORDER BY sh.outgoing_date DESC''',
    readsFrom: {db.shipments, db.items, db.products},
  ).get();
  return results
      .map((r) => {
            'id': r.read<String>('id'),
            'itemId': r.read<String>('item_id'),
            'sku': r.read<String>('sku'),
            'modelName': r.read<String>('model_name'),
            'trackingNumber': r.readNullable<String>('tracking_number'),
            'outgoingDate': r.readNullable<String>('outgoing_date'),
            'platform': r.readNullable<String>('platform'),
          })
      .toList();
});

class LogisticsScreen extends ConsumerWidget {
  const LogisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_allShipmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('물류 추적')),
      body: async.when(
        data: (shipments) {
          if (shipments.isEmpty) {
            return Center(
              child: Text('발송 이력이 없습니다',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textTertiary)),
            );
          }

          return Column(
            children: [
              // 요약
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    _SummaryChip('전체 ${shipments.length}건',
                        AppColors.primary),
                  ],
                ),
              ),
              // 목록
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: shipments.length,
                  itemBuilder: (_, i) {
                    final s = shipments[i];
                    return InkWell(
                      onTap: () => context.push('/item/${s['itemId']}'),
                      child: Container(
                        margin:
                            const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius:
                              BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withAlpha(30)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_shipping_outlined,
                                size: 20, color: AppColors.textTertiary),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s['modelName'] as String,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    s['sku'] as String,
                                    style: AppTheme.dataStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.textTertiary),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (s['trackingNumber'] != null)
                                  Text(
                                    s['trackingNumber'] as String,
                                    style: AppTheme.dataStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                  ),
                                if (s['outgoingDate'] != null)
                                  Text(
                                    s['outgoingDate'] as String,
                                    style: AppTheme.dataStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.textTertiary),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SummaryChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 13, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
