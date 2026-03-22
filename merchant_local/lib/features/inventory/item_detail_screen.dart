import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import 'status_actions.dart';

final _numFmt = NumberFormat('#,###');

/// 아이템 상세 Provider
final _itemProvider = FutureProvider.family<ItemData?, String>((ref, id) {
  return ref.watch(itemDaoProvider).getById(id);
});

final _purchaseProvider =
    FutureProvider.family<PurchaseData?, String>((ref, itemId) {
  return ref.watch(purchaseDaoProvider).getByItemId(itemId);
});

final _saleProvider =
    FutureProvider.family<SaleData?, String>((ref, itemId) {
  return ref.watch(saleDaoProvider).getByItemId(itemId);
});

final _adjustmentsProvider =
    FutureProvider.family<List<SaleAdjustmentData>, String>((ref, saleId) {
  return ref.watch(saleDaoProvider).getAdjustments(saleId);
});

final _statusLogsProvider =
    FutureProvider.family<List<StatusLogData>, String>((ref, itemId) {
  return ref.watch(subRecordDaoProvider).getStatusLogs(itemId);
});

final _shipmentsProvider =
    FutureProvider.family<List<ShipmentData>, String>((ref, itemId) {
  return ref.watch(subRecordDaoProvider).getShipments(itemId);
});

final _inspectionsProvider =
    FutureProvider.family<List<InspectionRejectionData>, String>(
        (ref, itemId) {
  return ref.watch(subRecordDaoProvider).getInspectionRejections(itemId);
});

final _repairsProvider =
    FutureProvider.family<List<RepairData>, String>((ref, itemId) {
  return ref.watch(subRecordDaoProvider).getRepairs(itemId);
});

/// 상품 정보 Provider
final _productProvider =
    FutureProvider.family<Product?, String>((ref, productId) {
  return ref.watch(masterDaoProvider).getProductById(productId);
});

/// 브랜드 정보 Provider
final _brandProvider =
    FutureProvider.family<Brand?, String>((ref, brandId) {
  return ref.watch(masterDaoProvider).getBrandById(brandId);
});

const _statusLabels = <String, String>{
  'ORDER_PLACED': '주문완료',
  'ORDER_CANCELLED': '주문취소',
  'OFFICE_STOCK': '사무실재고',
  'OUTGOING': '발송중',
  'IN_INSPECTION': '검수중',
  'LISTED': '리스팅',
  'SOLD': '판매완료',
  'SETTLED': '정산완료',
  'RETURNING': '반송중',
  'DEFECT_FOR_SALE': '불량판매',
  'DEFECT_SOLD': '불량판매완료',
  'DEFECT_SETTLED': '불량정산',
  'SUPPLIER_RETURN': '공급처반품',
  'DISPOSED': '폐기',
  'SAMPLE': '샘플',
  'DEFECT_HELD': '불량보류',
  'REPAIRING': '수선중',
};

Color _statusColor(String status) => switch (status) {
      'ORDER_PLACED' => Colors.orange,
      'OFFICE_STOCK' => Colors.blue,
      'OUTGOING' => Colors.indigo,
      'IN_INSPECTION' => Colors.purple,
      'LISTED' => Colors.teal,
      'SOLD' => Colors.green,
      'SETTLED' => Colors.grey,
      'RETURNING' => Colors.red,
      'DEFECT_FOR_SALE' || 'DEFECT_SOLD' => Colors.amber,
      'DEFECT_SETTLED' => Colors.grey,
      'DEFECT_HELD' => Colors.deepOrange,
      'REPAIRING' => Colors.brown,
      _ => Colors.blueGrey,
    };

class ItemDetailScreen extends ConsumerWidget {
  final String itemId;
  const ItemDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(_itemProvider(itemId));

    return Scaffold(
      appBar: AppBar(title: const Text('아이템 상세')),
      body: itemAsync.when(
        data: (item) {
          if (item == null) {
            return const Center(child: Text('아이템을 찾을 수 없습니다'));
          }
          return _ItemDetailBody(item: item);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
      floatingActionButton: itemAsync.whenOrNull(
        data: (item) {
          if (item == null) return null;
          final actions = statusActions[item.currentStatus];
          if (actions == null || actions.isEmpty) return null;
          return FloatingActionButton.extended(
            onPressed: () async {
              final result = await showStatusActionSheet(
                context: context,
                ref: ref,
                item: item,
              );
              if (result == true) {
                ref.invalidate(_itemProvider);
                ref.invalidate(_purchaseProvider);
                ref.invalidate(_saleProvider);
                ref.invalidate(_statusLogsProvider);
                ref.invalidate(_shipmentsProvider);
                ref.invalidate(_inspectionsProvider);
                ref.invalidate(_repairsProvider);
              }
            },
            icon: const Icon(Icons.swap_horiz),
            label: const Text('상태 변경'),
          );
        },
      ),
    );
  }
}

class _ItemDetailBody extends ConsumerWidget {
  final ItemData item;
  const _ItemDetailBody({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(_productProvider(item.productId));
    final purchaseAsync = ref.watch(_purchaseProvider(item.id));
    final saleAsync = ref.watch(_saleProvider(item.id));
    final statusLogsAsync = ref.watch(_statusLogsProvider(item.id));
    final shipmentsAsync = ref.watch(_shipmentsProvider(item.id));
    final inspectionsAsync = ref.watch(_inspectionsProvider(item.id));
    final repairsAsync = ref.watch(_repairsProvider(item.id));

    final statusLabel =
        _statusLabels[item.currentStatus] ?? item.currentStatus;
    final statusClr = _statusColor(item.currentStatus);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 기본 정보 카드 ──
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상품 이미지
                productAsync.when(
                  data: (product) {
                    final url = product?.imageUrl;
                    if (url == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          url, height: 120, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.sku,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusClr.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusClr,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 상품 정보
                productAsync.when(
                  data: (product) {
                    if (product == null) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow('모델', '${product.modelName} (${product.modelCode})'),
                        if (product.brandId != null)
                          ref.watch(_brandProvider(product.brandId!)).when(
                                data: (brand) => brand != null
                                    ? _InfoRow('브랜드', brand.name)
                                    : const SizedBox.shrink(),
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                        if (product.category != null)
                          _InfoRow('카테고리', product.category!),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                _InfoRow('사이즈', [
                  'KR ${item.sizeKr}',
                  if (item.sizeEu != null) 'EU ${item.sizeEu}',
                  if (item.sizeUs != null) 'US ${item.sizeUs}',
                ].join(' / ')),
                if (item.barcode != null) _InfoRow('바코드', item.barcode!),
                if (item.isPersonal) _InfoRow('구분', '개인용'),
                if (item.defectNote != null)
                  _InfoRow('불량메모', item.defectNote!),
                if (item.note != null) _InfoRow('비고', item.note!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── 매입 정보 ──
        purchaseAsync.when(
          data: (purchase) {
            if (purchase == null) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result =
                        await context.push('/item/${item.id}/purchase');
                    if (result == true) ref.invalidate(_purchaseProvider);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('매입 등록'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              );
            }
            return _SectionCard(
              title: '매입 정보',
              icon: Icons.shopping_cart,
              color: Colors.blue,
              trailing: IconButton(
                icon: const Icon(Icons.edit, size: 18),
                tooltip: '매입 수정',
                onPressed: () async {
                  final result = await context
                      .push('/item/${item.id}/purchase?edit=${purchase.id}');
                  if (result == true) ref.invalidate(_purchaseProvider);
                },
              ),
              children: [
                if (purchase.purchasePrice != null)
                  _InfoRow('매입가', '${_numFmt.format(purchase.purchasePrice)}원'),
                _InfoRow('결제수단', _paymentLabel(purchase.paymentMethod)),
                if (purchase.purchaseDate != null)
                  _InfoRow('매입일', purchase.purchaseDate!),
                if (purchase.vatRefundable != null &&
                    purchase.vatRefundable! > 0)
                  _InfoRow('부가세 환급',
                      '${_numFmt.format(purchase.vatRefundable!.round())}원'),
                if (purchase.memo != null) _InfoRow('메모', purchase.memo!),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // ── 판매 정보 ──
        saleAsync.when(
          data: (sale) {
            if (sale == null) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result =
                        await context.push('/item/${item.id}/sale');
                    if (result == true) ref.invalidate(_saleProvider);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('판매 등록'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              );
            }

            // 수익 계산
            final profitWidgets = <Widget>[];
            final purchaseData = ref.watch(_purchaseProvider(item.id));
            purchaseData.whenData((purchase) {
              if (purchase?.purchasePrice != null &&
                  sale.settlementAmount != null) {
                final profit = sale.settlementAmount! -
                    purchase!.purchasePrice! +
                    (purchase.vatRefundable?.round() ?? 0);
                final marginRate = purchase.purchasePrice! > 0
                    ? (profit / purchase.purchasePrice! * 100)
                    : 0.0;
                final profitColor = profit >= 0 ? Colors.green : Colors.red;
                profitWidgets.addAll([
                  _InfoRow('수익', '${_numFmt.format(profit)}원',
                      valueColor: profitColor),
                  _InfoRow(
                      '수익률', '${marginRate.toStringAsFixed(1)}%',
                      valueColor: profitColor),
                ]);
              }
            });

            return _SectionCard(
              title: '판매 정보',
              icon: Icons.sell,
              color: Colors.green,
              trailing: IconButton(
                icon: const Icon(Icons.edit, size: 18),
                tooltip: '판매 수정',
                onPressed: () async {
                  final result = await context
                      .push('/item/${item.id}/sale?edit=${sale.id}');
                  if (result == true) ref.invalidate(_saleProvider);
                },
              ),
              children: [
                _InfoRow('플랫폼', sale.platform),
                if (sale.listedPrice != null)
                  _InfoRow('등록가', '${_numFmt.format(sale.listedPrice)}원'),
                if (sale.sellPrice != null)
                  _InfoRow('판매가', '${_numFmt.format(sale.sellPrice)}원'),
                if (sale.platformFee != null)
                  _InfoRow('수수료',
                      '${_numFmt.format(sale.platformFee)}원 (${((sale.platformFeeRate ?? 0) * 100).toStringAsFixed(1)}%)'),
                if (sale.adjustmentTotal != 0)
                  _InfoRow(
                      '조정금', '${_numFmt.format(sale.adjustmentTotal)}원'),
                if (sale.settlementAmount != null)
                  _InfoRow('정산금',
                      '${_numFmt.format(sale.settlementAmount)}원',
                      valueColor: Colors.green),
                ...profitWidgets,
                if (sale.saleDate != null) _InfoRow('판매일', sale.saleDate!),
                if (sale.outgoingDate != null)
                  _InfoRow('발송일', sale.outgoingDate!),
                if (sale.settledAt != null) _InfoRow('정산일', sale.settledAt!),
                if (sale.trackingNumber != null)
                  _InfoRow('운송장', sale.trackingNumber!),
                if (sale.memo != null) _InfoRow('메모', sale.memo!),

                // 조정금 상세
                if (sale.adjustmentTotal != 0)
                  ref.watch(_adjustmentsProvider(sale.id)).when(
                        data: (adjustments) {
                          if (adjustments.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              Text('조정금 내역',
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                              for (final adj in adjustments)
                                _InfoRow(
                                  adj.type,
                                  '${_numFmt.format(adj.amount)}원${adj.memo != null ? ' (${adj.memo})' : ''}',
                                ),
                            ],
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // ── 배송 이력 ──
        shipmentsAsync.when(
          data: (shipments) {
            if (shipments.isEmpty) return const SizedBox.shrink();
            return _SectionCard(
              title: '배송 이력 (${shipments.length}건)',
              icon: Icons.local_shipping,
              color: Colors.indigo,
              children: [
                for (final s in shipments)
                  _InfoRow(
                    '#${s.seq} ${s.platform ?? ''}',
                    '${s.trackingNumber}${s.outgoingDate != null ? ' · ${s.outgoingDate}' : ''}',
                  ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // ── 검수 반려 ──
        inspectionsAsync.when(
          data: (inspections) {
            if (inspections.isEmpty) return const SizedBox.shrink();
            return _SectionCard(
              title: '검수 반려 (${inspections.length}건)',
              icon: Icons.warning,
              color: Colors.amber,
              children: [
                for (final ir in inspections) ...[
                  _InfoRow('#${ir.returnSeq} 반려일', ir.rejectedAt),
                  if (ir.reason != null) _InfoRow('사유', ir.reason!),
                  if (ir.defectType != null) _InfoRow('유형', ir.defectType!),
                  if (ir.discountAmount != null)
                    _InfoRow('할인', '${_numFmt.format(ir.discountAmount)}원'),
                  if (ir.memo != null) _InfoRow('메모', ir.memo!),
                  if (inspections.last != ir) const Divider(height: 12),
                ],
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // ── 수선 이력 ──
        repairsAsync.when(
          data: (repairs) {
            if (repairs.isEmpty) return const SizedBox.shrink();
            return _SectionCard(
              title: '수선 이력 (${repairs.length}건)',
              icon: Icons.build,
              color: Colors.brown,
              children: [
                for (final r in repairs) ...[
                  _InfoRow('시작', r.startedAt),
                  if (r.completedAt != null) _InfoRow('완료', r.completedAt!),
                  if (r.repairCost != null)
                    _InfoRow('비용', '${_numFmt.format(r.repairCost)}원'),
                  if (r.outcome != null) _InfoRow('결과', r.outcome!),
                  if (r.repairNote != null) _InfoRow('메모', r.repairNote!),
                  if (repairs.last != r) const Divider(height: 12),
                ],
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // ── 상태 변경 이력 ──
        statusLogsAsync.when(
          data: (logs) {
            if (logs.isEmpty) return const SizedBox.shrink();
            return _SectionCard(
              title: '상태 변경 이력 (${logs.length}건)',
              icon: Icons.history,
              color: Colors.grey,
              children: [
                for (final log in logs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        if (log.oldStatus != null) ...[
                          Text(
                            _statusLabels[log.oldStatus] ?? log.oldStatus!,
                            style: TextStyle(
                              color: _statusColor(log.oldStatus!),
                              fontSize: 12,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.arrow_forward,
                                size: 12, color: Colors.grey),
                          ),
                        ],
                        Text(
                          _statusLabels[log.newStatus] ?? log.newStatus,
                          style: TextStyle(
                            color: _statusColor(log.newStatus),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (log.changedAt != null)
                          Text(
                            _formatDate(log.changedAt!),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  String _paymentLabel(String method) => switch (method) {
        'CORPORATE_CARD' => '법인카드',
        'PERSONAL_CARD' => '개인카드',
        'CASH' => '현금',
        'TRANSFER' => '계좌이체',
        _ => method,
      };

  String _formatDate(String isoDate) {
    if (isoDate.length >= 10) return isoDate.substring(0, 10);
    return isoDate;
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget? trailing;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: valueColor,
                    fontWeight: valueColor != null ? FontWeight.w600 : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
