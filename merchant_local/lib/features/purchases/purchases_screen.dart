import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

final _wonFormat = NumberFormat('#,###');

final _purchasesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  final results = await db.customSelect(
    '''SELECT p.*, i.sku, i.id as item_id, i.size_kr, pr.model_name, pr.model_code,
              s.name as source_name
       FROM purchases p
       JOIN items i ON i.id = p.item_id
       JOIN products pr ON pr.id = i.product_id
       LEFT JOIN sources s ON s.id = p.source_id
       ORDER BY p.purchase_date DESC, p.created_at DESC''',
    readsFrom: {db.purchases, db.items, db.products, db.sources},
  ).get();
  return results
      .map((r) => {
            'id': r.read<String>('id'),
            'itemId': r.read<String>('item_id'),
            'sku': r.read<String>('sku'),
            'sizeKr': r.read<String>('size_kr'),
            'modelName': r.read<String>('model_name'),
            'modelCode': r.read<String>('model_code'),
            'purchasePrice': r.readNullable<int>('purchase_price'),
            'purchaseDate': r.readNullable<String>('purchase_date'),
            'paymentMethod': r.read<String>('payment_method'),
            'vatRefundable': r.readNullable<double>('vat_refundable'),
            'sourceName': r.readNullable<String>('source_name'),
          })
      .toList();
});

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_purchasesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('구매 내역')),
      body: async.when(
        data: (purchases) {
          if (purchases.isEmpty) {
            return Center(
              child: Text('구매 내역이 없습니다',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textTertiary)),
            );
          }

          // 요약 계산
          int totalCost = 0;
          double totalVat = 0;
          for (final p in purchases) {
            totalCost += (p['purchasePrice'] as int?) ?? 0;
            totalVat += (p['vatRefundable'] as double?) ?? 0;
          }

          return Column(
            children: [
              // 요약 카드
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    _StatCard('총 구매액', '${_wonFormat.format(totalCost)}원',
                        AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    _StatCard('VAT 환급', '${_wonFormat.format(totalVat.round())}원',
                        AppColors.success),
                    const SizedBox(width: AppSpacing.sm),
                    _StatCard('건수', '${purchases.length}건', AppColors.accent),
                  ],
                ),
              ),
              // 목록
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: purchases.length,
                  itemBuilder: (_, i) {
                    final p = purchases[i];
                    final price = p['purchasePrice'] as int?;
                    return InkWell(
                      onTap: () => context.push('/item/${p['itemId']}'),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p['modelName'] as String,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        p['sku'] as String,
                                        style: AppTheme.dataStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w400,
                                            color: AppColors.textTertiary),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Text(p['sizeKr'] as String,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    ],
                                  ),
                                  if (p['sourceName'] != null) ...[
                                    const SizedBox(height: 2),
                                    Text(p['sourceName'] as String,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color:
                                                    AppColors.textTertiary,
                                                fontSize: 11)),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (price != null)
                                  Text(
                                    '${_wonFormat.format(price)}원',
                                    style: AppTheme.dataStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700),
                                  ),
                                if (p['purchaseDate'] != null)
                                  Text(
                                    p['purchaseDate'] as String,
                                    style: AppTheme.dataStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.textTertiary),
                                  ),
                                Text(
                                  _paymentLabel(
                                      p['paymentMethod'] as String),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontSize: 10),
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: Theme.of(context).colorScheme.outline.withAlpha(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: AppTheme.dataStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

String _paymentLabel(String method) => switch (method) {
      'CORPORATE_CARD' => '법인카드',
      'PERSONAL_CARD' => '개인카드',
      'CASH' => '현금',
      'TRANSFER' => '계좌이체',
      _ => method,
    };
