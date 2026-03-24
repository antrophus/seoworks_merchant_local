import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import 'status_actions.dart';

final _numFmt = NumberFormat('#,###');

// ── Providers ──

final _itemProvider = FutureProvider.family<ItemData?, String>((ref, id) {
  return ref.watch(itemDaoProvider).getById(id);
});

final _purchaseProvider =
    FutureProvider.family<PurchaseData?, String>((ref, itemId) {
  return ref.watch(purchaseDaoProvider).getByItemId(itemId);
});

final _sourceProvider =
    FutureProvider.family<Source?, String>((ref, sourceId) async {
  final sources = await ref.watch(masterDaoProvider).getAllSources();
  return sources.cast<Source?>().firstWhere((s) => s!.id == sourceId,
      orElse: () => null);
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

final _productProvider =
    FutureProvider.family<Product?, String>((ref, productId) {
  return ref.watch(masterDaoProvider).getProductById(productId);
});

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

class ItemDetailScreen extends ConsumerWidget {
  final String itemId;
  const ItemDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(_itemProvider(itemId));

    return Scaffold(
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
          return FloatingActionButton(
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
            tooltip: '상태 변경',
            child: const Icon(Icons.swap_vert_rounded),
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
    final statusClr = statusColor(item.currentStatus);

    return CustomScrollView(
      slivers: [
        // ── 이미지 히어로 영역 (SliverAppBar + 플로팅 정보) ──
        SliverAppBar(
          expandedHeight: 320,
          pinned: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: AppColors.textPrimary,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(200),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, size: 20),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: productAsync.when(
              data: (product) => _HeroImage(
                imageUrl: product?.imageUrl,
                modelCode: product?.modelCode,
                modelName: product?.modelName,
                sizeKr: item.sizeKr,
                sizeEu: item.sizeEu,
                statusLabel: statusLabel,
                statusColor: statusClr,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ),

        // ── 상품 기본 정보 ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: productAsync.when(
              data: (product) {
                if (product == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 모델코드만 표시
                    Text(
                      product.modelCode,
                      style: AppTheme.dataStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // 브랜드 · 카테고리 · 사이즈
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: 4,
                      children: [
                        if (product.brandId != null)
                          ref.watch(_brandProvider(product.brandId!)).when(
                                data: (brand) => brand != null
                                    ? _InfoChip(brand.name)
                                    : const SizedBox.shrink(),
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                        if (product.category != null)
                          _InfoChip(product.category!),
                        _InfoChip(
                          [
                            'KR ${item.sizeKr}',
                            if (item.sizeEu != null) 'EU ${item.sizeEu}',
                            if (item.sizeUs != null) 'US ${item.sizeUs}',
                          ].join(' / '),
                        ),
                      ],
                    ),
                    if (item.barcode != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '바코드: ${item.barcode}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (item.isPersonal)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('개인용',
                              style: TextStyle(
                                  color: AppColors.accent, fontSize: 11)),
                        ),
                      ),
                    if (item.defectNote != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('불량: ${item.defectNote}',
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 12)),
                      ),
                    if (item.note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('비고: ${item.note}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // ── 매입 정보 ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: purchaseAsync.when(
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
                  icon: Icons.shopping_cart_outlined,
                  color: AppColors.primary,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: '매입 수정',
                    onPressed: () async {
                      final result = await context
                          .push('/item/${item.id}/purchase?edit=${purchase.id}');
                      if (result == true) ref.invalidate(_purchaseProvider);
                    },
                  ),
                  children: [
                    if (purchase.purchasePrice != null)
                      _InfoRow('매입가',
                          '${_numFmt.format(purchase.purchasePrice)}원'),
                    _InfoRow('결제수단', _paymentLabel(purchase.paymentMethod)),
                    if (purchase.sourceId != null)
                      _SourceRow(sourceId: purchase.sourceId!),
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
          ),
        ),

        // ── 판매 정보 ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: saleAsync.when(
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
                    final profitColor =
                        profit >= 0 ? AppColors.success : AppColors.error;
                    profitWidgets.addAll([
                      _InfoRow('수익', '${_numFmt.format(profit)}원',
                          valueColor: profitColor),
                      _InfoRow('수익률', '${marginRate.toStringAsFixed(1)}%',
                          valueColor: profitColor),
                    ]);
                  }
                });

                return _SectionCard(
                  title: '판매 정보',
                  icon: Icons.sell_outlined,
                  color: AppColors.success,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
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
                      _InfoRow(
                          '정산금', '${_numFmt.format(sale.settlementAmount)}원',
                          valueColor: AppColors.success),
                    ...profitWidgets,
                    if (sale.saleDate != null) _InfoRow('판매일', sale.saleDate!),
                    if (sale.outgoingDate != null)
                      _InfoRow('발송일', sale.outgoingDate!),
                    if (sale.settledAt != null)
                      _InfoRow('정산일', sale.settledAt!),
                    if (sale.trackingNumber != null)
                      _InfoRow('운송장', sale.trackingNumber!),
                    if (sale.memo != null) _InfoRow('메모', sale.memo!),
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall),
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
          ),
        ),

        // ── 배송 이력 ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: shipmentsAsync.when(
              data: (shipments) {
                if (shipments.isEmpty) return const SizedBox.shrink();
                return _SectionCard(
                  title: '배송 이력 (${shipments.length}건)',
                  icon: Icons.local_shipping_outlined,
                  color: AppColors.statusOutgoing,
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
          ),
        ),

        // ── 검수 반려 ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: inspectionsAsync.when(
              data: (inspections) {
                if (inspections.isEmpty) return const SizedBox.shrink();
                return _SectionCard(
                  title: '검수 반려 (${inspections.length}건)',
                  icon: Icons.warning_amber_outlined,
                  color: AppColors.warning,
                  children: [
                    for (final ir in inspections) ...[
                      _InfoRow('#${ir.returnSeq} 반려일', ir.rejectedAt),
                      if (ir.reason != null) _InfoRow('사유', ir.reason!),
                      if (ir.defectType != null) _InfoRow('유형', ir.defectType!),
                      if (ir.discountAmount != null)
                        _InfoRow(
                            '할인', '${_numFmt.format(ir.discountAmount)}원'),
                      if (ir.memo != null) _InfoRow('메모', ir.memo!),
                      if (inspections.last != ir) const Divider(height: 12),
                    ],
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ),

        // ── 수선 이력 ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: repairsAsync.when(
              data: (repairs) {
                if (repairs.isEmpty) return const SizedBox.shrink();
                return _SectionCard(
                  title: '수선 이력 (${repairs.length}건)',
                  icon: Icons.build_outlined,
                  color: AppColors.statusRepairing,
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
          ),
        ),

        // ── 상태 변경 이력 ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: statusLogsAsync.when(
              data: (logs) {
                if (logs.isEmpty) return const SizedBox.shrink();
                return _SectionCard(
                  title: '상태 변경 이력 (${logs.length}건)',
                  icon: Icons.history,
                  color: AppColors.textTertiary,
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
                                  color: statusColor(log.oldStatus!),
                                  fontSize: 12,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.arrow_forward,
                                    size: 12, color: AppColors.textTertiary),
                              ),
                            ],
                            Text(
                              _statusLabels[log.newStatus] ?? log.newStatus,
                              style: TextStyle(
                                color: statusColor(log.newStatus),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            if (log.changedAt != null)
                              Text(
                                _formatDate(log.changedAt!),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary),
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
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
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

// ── 히어로 이미지 + 플로팅 정보 오버레이 ──

class _HeroImage extends StatelessWidget {
  final String? imageUrl;
  final String? modelCode;
  final String? modelName;
  final String sizeKr;
  final String? sizeEu;
  final String statusLabel;
  final Color statusColor;

  const _HeroImage({
    this.imageUrl,
    this.modelCode,
    this.modelName,
    required this.sizeKr,
    this.sizeEu,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 배경 이미지 (가득 채움)
        if (imageUrl != null && imageUrl!.isNotEmpty)
          CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: AppColors.surfaceVariant,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, __, ___) => Container(
              color: AppColors.surfaceVariant,
              child: const Icon(Icons.inventory_2,
                  size: 64, color: AppColors.textTertiary),
            ),
          )
        else
          Container(
            color: AppColors.surfaceVariant,
            child: const Icon(Icons.inventory_2,
                size: 64, color: AppColors.textTertiary),
          ),

        // 하단 그라데이션 오버레이
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 160,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withAlpha(140),
                  Colors.black.withAlpha(200),
                ],
              ),
            ),
          ),
        ),

        // 플로팅 정보 레이어
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상태 뱃지
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(220),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 모델명
              if (modelName != null)
                Text(
                  modelName!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 4),

              // 사이즈
              Text(
                'KR $sizeKr${sizeEu != null ? '  ·  EU $sizeEu' : ''}',
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 정보 칩 (브랜드, 카테고리, 사이즈 등) ──

class _InfoChip extends StatelessWidget {
  final String text;
  const _InfoChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

// ── 섹션 카드 ──

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

class _SourceRow extends ConsumerWidget {
  final String sourceId;
  const _SourceRow({required this.sourceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_sourceProvider(sourceId));
    return async.when(
      data: (source) => source != null
          ? _InfoRow('매입처', source.name)
          : const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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
                  ?.copyWith(color: AppColors.textTertiary),
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
