import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/fullscreen_image_viewer.dart';
import '../inventory/inventory_providers.dart' show fmt, productImage, statusLabels;

// ══════════════════════════════════════════════════
// Providers
// ══════════════════════════════════════════════════

final _defectItemsProvider = StreamProvider<List<ItemData>>((ref) {
  return ref.watch(itemDaoProvider).watchByStatuses(
      ['DEFECT_FOR_SALE', 'DEFECT_HELD', 'DEFECT_SOLD', 'RETURNING']);
});

final _allRejectionsProvider =
    FutureProvider<List<InspectionRejectionData>>((ref) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.inspectionRejections)
        ..orderBy([(t) => OrderingTerm.desc(t.rejectedAt)]))
      .get();
});

final _exProductProvider =
    FutureProvider.family<Product?, String>((ref, productId) {
  return ref.watch(masterDaoProvider).getProductById(productId);
});

final _exItemProvider =
    FutureProvider.family<ItemData?, String>((ref, itemId) {
  return ref.watch(itemDaoProvider).getById(itemId);
});

final _exInspectionsProvider =
    FutureProvider.family<List<InspectionRejectionData>, String>(
        (ref, itemId) {
  return ref.watch(subRecordDaoProvider).getInspectionRejections(itemId);
});

// ══════════════════════════════════════════════════
// Screen
// ══════════════════════════════════════════════════

class ExceptionsScreen extends ConsumerWidget {
  const ExceptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('하자 관리'),
          bottom: const TabBar(
            tabs: [Tab(text: '현재 하자'), Tab(text: '반려 이력')],
          ),
        ),
        body: const TabBarView(
          children: [_CurrentDefectsTab(), _RejectionHistoryTab()],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 현재 하자 탭
// ══════════════════════════════════════════════════

class _CurrentDefectsTab extends ConsumerWidget {
  const _CurrentDefectsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_defectItemsProvider);
    return async.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 56,
                    color: AppColors.success.withAlpha(180)),
                const SizedBox(height: 12),
                Text('현재 하자 아이템이 없습니다',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textTertiary)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: items.length,
          itemBuilder: (_, i) => _DefectItemCard(item: items[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

class _DefectItemCard extends ConsumerWidget {
  final ItemData item;
  const _DefectItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(_exProductProvider(item.productId));
    final inspectionsAsync = ref.watch(_exInspectionsProvider(item.id));
    final statusClr = statusColor(item.currentStatus);
    final statusLbl = _statusLabel(item.currentStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => context.push('/item/${item.id}'),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 헤더: 이미지 + 제품명 + 상태 뱃지 ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  productAsync.when(
                    data: (p) => productImage(p?.imageUrl, size: 56),
                    loading: () =>
                        const SizedBox(width: 56, height: 56),
                    error: (_, __) =>
                        const SizedBox(width: 56, height: 56),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: productAsync.when(
                                data: (p) => Text(
                                  p?.modelName ?? item.sku,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                loading: () => Text(item.sku,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                error: (_, __) => Text(item.sku),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusClr.withAlpha(20),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Text(statusLbl,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: statusClr,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '사이즈: ${item.sizeKr}${item.sizeEu != null ? " / EU ${item.sizeEu}" : ""}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (item.defectNote != null &&
                            item.defectNote!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text('불량: ${item.defectNote}',
                                style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 11)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── 최신 검수반려 인라인 ──
              inspectionsAsync.when(
                data: (list) {
                  if (list.isEmpty) return const SizedBox.shrink();
                  return _InlineRejectionCard(rejection: list.last);
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 반려 이력 탭
// ══════════════════════════════════════════════════

class _RejectionHistoryTab extends ConsumerWidget {
  const _RejectionHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_allRejectionsProvider);
    return async.when(
      data: (rejections) {
        if (rejections.isEmpty) {
          return Center(
            child: Text('반려 이력이 없습니다',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textTertiary)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: rejections.length,
          itemBuilder: (_, i) =>
              _RejectionCard(rejection: rejections[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

class _RejectionCard extends ConsumerWidget {
  final InspectionRejectionData rejection;
  const _RejectionCard({required this.rejection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(_exItemProvider(rejection.itemId));

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => context.push('/item/${rejection.itemId}'),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 아이템 + 제품 정보 ──
              itemAsync.when(
                data: (item) {
                  if (item == null) return const SizedBox.shrink();
                  final productAsync =
                      ref.watch(_exProductProvider(item.productId));
                  return Row(
                    children: [
                      productAsync.when(
                        data: (p) => productImage(p?.imageUrl, size: 44),
                        loading: () =>
                            const SizedBox(width: 44, height: 44),
                        error: (_, __) =>
                            const SizedBox(width: 44, height: 44),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: productAsync.when(
                                    data: (p) => Text(
                                      p?.modelName ?? item.sku,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    loading: () => Text(item.sku),
                                    error: (_, __) => Text(item.sku),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _StatusBadge(item.currentStatus),
                              ],
                            ),
                            Text(
                              '${item.sizeKr}${item.sizeEu != null ? " / EU ${item.sizeEu}" : ""}  ·  ${item.sku}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(height: 44),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.sm),
              _InlineRejectionCard(rejection: rejection),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 공용 인라인 반려 카드 (현재하자 + 반려이력 공유)
// ══════════════════════════════════════════════════

class _InlineRejectionCard extends StatelessWidget {
  final InspectionRejectionData rejection;
  const _InlineRejectionCard({required this.rejection});

  @override
  Widget build(BuildContext context) {
    final defectLabel = switch (rejection.defectType) {
      'DEFECT_SALE' => '불량판매',
      'DEFECT_HELD' => '불량보류',
      'DEFECT_RETURN' => '반송',
      _ => rejection.defectType ?? '검수반려',
    };
    final photoUrls = _parsePhotoUrls(rejection.photoUrls);
    final dateStr = rejection.rejectedAt.length >= 10
        ? rejection.rejectedAt.substring(0, 10)
        : rejection.rejectedAt;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 반려 헤더: 시퀀스 + 유형 + 날짜 ──
          Row(
            children: [
              const Icon(Icons.warning_amber,
                  size: 14, color: AppColors.warning),
              const SizedBox(width: 4),
              Text(
                '검수반려 #${rejection.returnSeq}  ·  $defectLabel',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning),
              ),
              const Spacer(),
              Text(dateStr,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary)),
            ],
          ),

          // ── 할인금액 ──
          if (rejection.discountAmount != null) ...[
            const SizedBox(height: 3),
            Text(
              '할인 -${fmt.format(rejection.discountAmount)}원',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error),
            ),
          ],

          // ── 사유 ──
          if (rejection.reason != null && rejection.reason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              rejection.reason!,
              style: const TextStyle(fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // ── 메모 ──
          if (rejection.memo != null && rejection.memo!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              rejection.memo!,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // ── 사진 썸네일 ──
          if (photoUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photoUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => FullscreenImageViewer.open(
                      context,
                      imageUrls: photoUrls,
                      initialIndex: i,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        photoUrls[i],
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 64,
                          height: 64,
                          color: AppColors.surfaceVariant,
                          child: const Icon(Icons.broken_image, size: 24),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
    return trimmed
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

// ══════════════════════════════════════════════════
// 유틸
// ══════════════════════════════════════════════════

String _statusLabel(String s) => switch (s) {
      'DEFECT_FOR_SALE' => '하자판매',
      'DEFECT_HELD' => '하자보류',
      'DEFECT_SOLD' => '하자판매완료',
      'RETURNING' => '반송중',
      _ => s,
    };

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    final label = statusLabels[status] ?? status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
