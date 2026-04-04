import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../inventory_providers.dart';
import '../status_actions.dart';

// ══════════════════════════════════════════════════
// 아이템 타일
// ══════════════════════════════════════════════════

class ItemTile extends ConsumerWidget {
  final ItemData item;
  final SaleData? sale;
  final PurchaseData? purchase;
  final Product? product;
  final String? sourceName;

  const ItemTile({
    super.key,
    required this.item,
    this.sale,
    this.purchase,
    this.product,
    this.sourceName,
  });

  static const _defectStatuses = {
    'REPAIRING', 'RETURNING', 'DEFECT_FOR_SALE', 'DEFECT_HELD',
    'DEFECT_SOLD', 'DEFECT_SETTLED', 'SUPPLIER_RETURN',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 자기 ID만 구독 → 다른 아이템 선택/해제 시 rebuild 안 됨
    final selected = ref.watch(
        selectionProvider.select((ids) => ids.contains(item.id)));
    final isActive = ref.watch(
        selectionProvider.select((ids) => ids.isNotEmpty));
    final selectionEnabled = ref.watch(selectionEnabledProvider);

    final statusLabel = statusLabels[item.currentStatus] ?? item.currentStatus;
    final statusClr = statusColor(item.currentStatus);
    final showDefect = _defectStatuses.contains(item.currentStatus);

    final highlight = ref.watch(overdueHighlightMode);
    int? overdueDays;
    if (highlight && item.currentStatus == 'IN_INSPECTION') {
      final updated = DateTime.tryParse(item.updatedAt ?? '');
      if (updated != null) {
        final days = DateTime.now().difference(updated).inDays;
        if (days >= 12) overdueDays = days;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: selected
          ? AppColors.primary.withAlpha(15)
          : overdueDays != null
              ? AppColors.error.withAlpha(10)
              : null,
      child: InkWell(
        onTap: () {
          if (isActive) {
            ref.read(selectionProvider.notifier).toggle(item.id);
          } else {
            context.push('/item/${item.id}');
          }
        },
        onLongPress: selectionEnabled ? () {
          if (!isActive) {
            ref.read(selectionProvider.notifier).toggle(item.id);
          } else {
            showStatusActionSheet(
                context: context, ref: ref, item: item).then((result) {
              if (result == true) {
                ref.invalidate(itemsProvider);
                ref.invalidate(itemStatusCountsProvider);
              }
            });
          }
        } : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () =>
                    ref.read(selectionProvider.notifier).toggle(item.id),
                child: Stack(
                  children: [
                    productImage(product?.imageUrl, size: 64),
                    Positioned(
                      top: 2,
                      left: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : (isActive ? Colors.black38 : Colors.black12),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          selected ? Icons.check : Icons.circle_outlined,
                          color: selected
                              ? Colors.white
                              : (isActive ? Colors.white : Colors.white54),
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                            product?.modelName ?? item.sku,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusClr.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(statusLabel,
                            style: TextStyle(
                                color: statusClr,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (statusActions.containsKey(item.currentStatus))
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            icon: Icon(Icons.swap_horiz,
                                size: 16, color: statusClr),
                            padding: EdgeInsets.zero,
                            tooltip: '상태 변경',
                            onPressed: () async {
                              final r = await showStatusActionSheet(
                                  context: context, ref: ref, item: item);
                              if (r == true) {
                                ref.invalidate(itemsProvider);
                                ref.invalidate(itemStatusCountsProvider);
                              }
                            },
                          ),
                        ),
                    ]),
                    const SizedBox(height: 4),

                    Text(
                      '사이즈: ${item.sizeKr}${item.sizeEu != null ? " / EU ${item.sizeEu}" : ""}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),

                    if (purchase != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '매입: ${purchase!.purchasePrice != null ? "${fmt.format(purchase!.purchasePrice)}원" : "-"}'
                          '${sourceName != null ? "  ·  $sourceName" : ""}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.primary),
                        ),
                      ),

                    if (sale != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '판매: ${sale!.sellPrice != null ? "${fmt.format(sale!.sellPrice)}원" : "-"}'
                          ' → 정산: ${sale!.settlementAmount != null ? "${fmt.format(sale!.settlementAmount)}원" : "-"}'
                          '  ·  ${sale!.platform}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.success),
                        ),
                      ),

                    if (showDefect) DefectLoader(itemId: item.id),
                    if (item.currentStatus == 'REPAIRING')
                      RepairLoader(itemId: item.id),

                    if (item.defectNote != null && item.defectNote!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('불량: ${item.defectNote}',
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),

                    if (overdueDays != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '검수 $overdueDays일 경과',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ),

                    if (item.isPersonal)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('개인용',
                            style: TextStyle(
                                color: AppColors.accent, fontSize: 11)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 불량/수선 로더
// ══════════════════════════════════════════════════

class DefectLoader extends ConsumerWidget {
  final String itemId;
  const DefectLoader({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_latestInspectionProvider(itemId));
    return async.when(
      data: (i) => i != null ? DefectChip(inspection: i) : const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

final _latestInspectionProvider =
    FutureProvider.family<InspectionRejectionData?, String>(
        (ref, itemId) async {
  final list =
      await ref.watch(subRecordDaoProvider).getInspectionRejections(itemId);
  return list.isNotEmpty ? list.last : null;
});

class RepairLoader extends ConsumerWidget {
  final String itemId;
  const RepairLoader({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_latestRepairProvider(itemId));
    return async.when(
      data: (r) => r != null ? RepairChip(repair: r) : const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

final _latestRepairProvider =
    FutureProvider.family<RepairData?, String>((ref, itemId) async {
  final list = await ref.watch(subRecordDaoProvider).getRepairs(itemId);
  return list.isNotEmpty ? list.first : null;
});

// ══════════════════════════════════════════════════
// 검수반려/수선 칩
// ══════════════════════════════════════════════════

class DefectChip extends StatelessWidget {
  final InspectionRejectionData inspection;
  const DefectChip({super.key, required this.inspection});

  @override
  Widget build(BuildContext context) {
    final defectLabel = switch (inspection.defectType) {
      'DEFECT_SALE' => '불량판매',
      'DEFECT_HELD' => '불량보류',
      'DEFECT_RETURN' => '반송',
      _ => inspection.defectType ?? '검수반려',
    };

    final photoUrls = _parsePhotoUrls(inspection.photoUrls);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.warning.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber, size: 14, color: AppColors.warning),
                const SizedBox(width: 4),
                Text(
                  '검수반려 #${inspection.returnSeq} ($defectLabel)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
                if (inspection.discountAmount != null) ...[
                  const Spacer(),
                  Text(
                    '-${fmt.format(inspection.discountAmount)}원',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
            if (inspection.reason != null && inspection.reason!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  inspection.reason!,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (inspection.memo != null && inspection.memo!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  inspection.memo!,
                  style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (photoUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photoUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 4),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        photoUrls[i],
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          color: AppColors.surfaceVariant,
                          child: const Icon(Icons.broken_image, size: 20),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _parsePhotoUrls(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final trimmed = raw.trim();
    if (trimmed.startsWith('[')) {
      return trimmed
          .substring(1, trimmed.length - 1)
          .split(',')
          .map((s) => s.trim().replaceAll('"', '').replaceAll("'", ''))
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return trimmed.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
}

class RepairChip extends StatelessWidget {
  final RepairData repair;
  const RepairChip({super.key, required this.repair});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.statusRepairing.withAlpha(15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.statusRepairing.withAlpha(60)),
        ),
        child: Text(
          '수선중 (${repair.startedAt}~)'
          '${repair.repairNote != null ? " — ${repair.repairNote}" : ""}',
          style: const TextStyle(fontSize: 10, color: AppColors.statusRepairing),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
