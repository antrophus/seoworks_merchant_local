import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

final _defectItemsProvider =
    StreamProvider<List<ItemData>>((ref) {
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

class _CurrentDefectsTab extends ConsumerWidget {
  const _CurrentDefectsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_defectItemsProvider);
    return async.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text('하자 아이템이 없습니다',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textTertiary)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            final color = statusColor(item.currentStatus);
            return InkWell(
              onTap: () => context.push('/item/${item.id}'),
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withAlpha(30)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.sku,
                              style: AppTheme.dataStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          Text(item.sizeKr,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withAlpha(20),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        _statusLabel(item.currentStatus),
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

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
          itemBuilder: (_, i) {
            final r = rejections[i];
            return InkWell(
              onTap: () => context.push('/item/${r.itemId}'),
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withAlpha(30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (r.defectType != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm, vertical: 2),
                            margin:
                                const EdgeInsets.only(right: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.error.withAlpha(15),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(r.defectType!,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.error)),
                          ),
                        if (r.rejectedAt.isNotEmpty)
                          Text(r.rejectedAt,
                              style: AppTheme.dataStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textTertiary)),
                        const Spacer(),
                        if (r.discountAmount != null)
                          Text('-${r.discountAmount}원',
                              style: AppTheme.dataStyle(
                                  fontSize: 12, color: AppColors.error)),
                      ],
                    ),
                    if (r.reason != null && r.reason!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(r.reason!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

String _statusLabel(String s) => switch (s) {
      'DEFECT_FOR_SALE' => '하자판매',
      'DEFECT_HELD' => '하자보류',
      'DEFECT_SOLD' => '하자판매완료',
      'RETURNING' => '반송중',
      _ => s,
    };
