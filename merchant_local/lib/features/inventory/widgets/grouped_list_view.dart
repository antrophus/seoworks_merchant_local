import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../inventory_providers.dart';
import 'item_tile.dart';

// ══════════════════════════════════════════════════
// 관련 데이터 모델
// ══════════════════════════════════════════════════

class ItemWithRelated {
  final ItemData item;
  final SaleData? sale;
  final PurchaseData? purchase;
  final Product? product;
  final String? sourceName;
  const ItemWithRelated(
      {required this.item, this.sale, this.purchase, this.product, this.sourceName});
}

class ItemGroup {
  final String title;
  final String? subtitle;
  final String sortDate;
  final String summaryLine;
  final List<ItemWithRelated> items;
  final bool isSettlement;
  final bool isListed;
  final bool showGroupSelect;

  const ItemGroup({
    required this.title,
    this.subtitle,
    required this.sortDate,
    required this.summaryLine,
    required this.items,
    this.isSettlement = false,
    this.isListed = false,
    this.showGroupSelect = false,
  });
}

// ══════════════════════════════════════════════════
// 배치 데이터 로딩 믹스인
// ══════════════════════════════════════════════════

mixin BatchDataLoader<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Map<String, SaleData> sales = {};
  Map<String, PurchaseData> purchases = {};
  Map<String, Product> products = {};
  Map<String, Source> sources = {};
  bool loaded = false;

  /// id:updatedAt 조합으로 실제 변경 여부 판단 (reference 비교 대신 사용)
  String _itemsKey(List<ItemData> items) =>
      items.map((i) => '${i.id}:${i.updatedAt}').join();

  Future<void> loadBatchData(List<ItemData> items) async {
    final ids = items.map((i) => i.id).toList();
    final productIds = items.map((i) => i.productId).toSet().toList();

    // 4개 쿼리 동시 시작 (N+1 → 각 1회 쿼리)
    final salesFuture = ref.read(saleDaoProvider).getByItemIds(ids);
    final purchasesFuture = ref.read(purchaseDaoProvider).getByItemIds(ids);
    final sourcesFuture = ref.read(masterDaoProvider).getAllSourcesMap();
    final productsFuture = ref.read(masterDaoProvider).getProductsByIds(productIds);

    final salesResult = await salesFuture;
    final purchasesResult = await purchasesFuture;
    final sourcesResult = await sourcesFuture;
    final productMap = await productsFuture;

    if (mounted) {
      setState(() {
        sales = salesResult;
        purchases = purchasesResult;
        products = productMap;
        sources = sourcesResult;
        loaded = true;
      });
    }
  }
}

// ══════════════════════════════════════════════════
// 배치 로딩 플랫 리스트
// ══════════════════════════════════════════════════

class BatchListView extends ConsumerStatefulWidget {
  final List<ItemData> items;

  const BatchListView({
    super.key,
    required this.items,
  });
  @override
  ConsumerState<BatchListView> createState() => _BatchListViewState();
}

class _BatchListViewState extends ConsumerState<BatchListView>
    with BatchDataLoader {
  @override
  void initState() {
    super.initState();
    loadBatchData(widget.items);
  }

  @override
  void didUpdateWidget(covariant BatchListView old) {
    super.didUpdateWidget(old);
    if (_itemsKey(old.items) != _itemsKey(widget.items)) {
      loadBatchData(widget.items);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const Center(child: CircularProgressIndicator());

    return ListView.builder(
      itemCount: widget.items.length,
      itemBuilder: (_, i) {
        final item = widget.items[i];
        final purchase = purchases[item.id];
        return ItemTile(
          item: item,
          sale: sales[item.id],
          purchase: purchase,
          product: products[item.productId],
          sourceName: purchase?.sourceId != null
              ? sources[purchase!.sourceId]?.name
              : null,
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════
// 그룹 뷰
// ══════════════════════════════════════════════════

class GroupedListView extends ConsumerStatefulWidget {
  final List<ItemData> items;
  final String filterCsv;

  const GroupedListView({
    super.key,
    required this.items,
    required this.filterCsv,
  });
  @override
  ConsumerState<GroupedListView> createState() => _GroupedListViewState();
}

class _GroupedListViewState extends ConsumerState<GroupedListView>
    with BatchDataLoader {
  @override
  void initState() {
    super.initState();
    loadBatchData(widget.items);
  }

  @override
  void didUpdateWidget(covariant GroupedListView old) {
    super.didUpdateWidget(old);
    if (_itemsKey(old.items) != _itemsKey(widget.items)) {
      loadBatchData(widget.items);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const Center(child: CircularProgressIndicator());

    final groups = _buildGroups();
    if (groups.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (_, i) => GroupCard(group: groups[i]),
    );
  }

  List<ItemWithRelated> _wrap(List<ItemData> items) {
    return items.map((item) {
      final purchase = purchases[item.id];
      return ItemWithRelated(
        item: item,
        sale: sales[item.id],
        purchase: purchase,
        product: products[item.productId],
        sourceName: purchase?.sourceId != null
            ? sources[purchase!.sourceId]?.name
            : null,
      );
    }).toList();
  }

  List<ItemGroup> _buildGroups() {
    final statuses = widget.filterCsv.split(',').toSet();

    // 판매중 (리스팅/포이즌보관) → 상품별 그룹
    if (statuses.intersection({'LISTED', 'POIZON_STORAGE'}).isNotEmpty &&
        statuses.intersection({'OUTGOING', 'IN_INSPECTION', 'OFFICE_STOCK'}).isEmpty) {
      return _groupBy(
        keyFn: (item) => item.productId,
        titleFn: (key) {
          final product = products[key];
          return product?.modelName ?? key;
        },
        summaryFn: (items) {
          final total = items.fold<int>(
              0, (s, r) => s + (r.purchase?.purchasePrice ?? 0));
          return total > 0 ? '매입가합 ${fmt.format(total)}원' : '';
        },
        isListed: true,
      );
    }

    // 발송중/검수중 → 발송일+송장 (오래된 발송일 우선 고정)
    if (statuses.intersection({'OUTGOING', 'IN_INSPECTION'}).isNotEmpty &&
        statuses.intersection({'OFFICE_STOCK', 'LISTED'}).isEmpty) {
      return _groupBy(
        keyFn: (item) {
          final s = sales[item.id];
          return '${s?.outgoingDate ?? "날짜미상"}|${s?.trackingNumber ?? "송장없음"}';
        },
        titleFn: (key) => key.split('|')[0],
        subtitleFn: (key) => key.split('|')[1],
        summaryFn: (items) =>
            '판매가합 ${fmt.format(items.fold<int>(0, (s, r) => s + (r.sale?.sellPrice ?? 0)))}원',
        forceAsc: true,
        showGroupSelect: true,
      );
    }

    // 정산완료
    if (statuses.intersection({'SETTLED', 'DEFECT_SETTLED'}).isNotEmpty &&
        statuses.length <= 2) {
      return _groupBy(
        keyFn: (item) => sales[item.id]?.settledAt ?? '날짜미상',
        titleFn: (key) => key == '날짜미상' ? '정산일 미상' : key,
        summaryFn: (_) => '',
        isSettlement: true,
      );
    }

    // 기타 → 매입일
    return _groupBy(
      keyFn: (item) => purchases[item.id]?.purchaseDate ?? '날짜미상',
      titleFn: (key) => key == '날짜미상' ? '매입일 미상' : key,
      summaryFn: (items) {
        final total = items.fold<int>(0, (s, r) =>
            s + (r.sale?.listedPrice ?? r.sale?.sellPrice ?? r.purchase?.purchasePrice ?? 0));
        return '${fmt.format(total)}원';
      },
    );
  }

  List<ItemGroup> _groupBy({
    required String Function(ItemData) keyFn,
    required String Function(String key) titleFn,
    String Function(String key)? subtitleFn,
    required String Function(List<ItemWithRelated>) summaryFn,
    bool isSettlement = false,
    bool isListed = false,
    bool showGroupSelect = false,
    bool? forceAsc,
  }) {
    final grouped = <String, List<ItemData>>{};
    for (final item in widget.items) {
      grouped.putIfAbsent(keyFn(item), () => []).add(item);
    }

    final groups = grouped.entries.map((e) {
      final wrapped = _wrap(e.value);
      String sortDate = e.key;
      if (isListed) {
        final dates = wrapped
            .map((r) => r.purchase?.purchaseDate)
            .where((d) => d != null)
            .cast<String>()
            .toList()..sort();
        if (dates.isNotEmpty) sortDate = dates.first;
      }
      return ItemGroup(
        title: titleFn(e.key),
        subtitle: subtitleFn?.call(e.key),
        sortDate: sortDate,
        summaryLine: summaryFn(wrapped),
        items: wrapped,
        isSettlement: isSettlement,
        isListed: isListed,
        showGroupSelect: showGroupSelect,
      );
    }).toList();

    groups.sort((a, b) {
      final bool asc = forceAsc ?? ref.read(inventorySortAscProvider);
      if (isListed) {
        final cmp = asc
            ? a.items.length.compareTo(b.items.length)
            : b.items.length.compareTo(a.items.length);
        if (cmp != 0) return cmp;
        return asc
            ? b.sortDate.compareTo(a.sortDate)
            : a.sortDate.compareTo(b.sortDate);
      }
      return asc
          ? a.sortDate.compareTo(b.sortDate)
          : b.sortDate.compareTo(a.sortDate);
    });
    return groups;
  }
}

// ══════════════════════════════════════════════════
// 그룹 카드
// ══════════════════════════════════════════════════

class GroupCard extends ConsumerWidget {
  final ItemGroup group;
  const GroupCard({super.key, required this.group});

  /// 그룹 내 12일 이상 경과된 IN_INSPECTION 아이템 수
  int _overdueCount() {
    final cutoff = DateTime.now().subtract(const Duration(days: 12));
    return group.items.where((r) {
      if (r.item.currentStatus != 'IN_INSPECTION') return false;
      final updated = DateTime.tryParse(r.item.updatedAt ?? '');
      return updated != null && updated.isBefore(cutoff);
    }).length;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupIds = group.items.map((r) => r.item.id).toSet();
    final selectedIds = ref.watch(selectionProvider);
    final isActive = selectedIds.isNotEmpty;
    final allSelected = isActive && groupIds.every(selectedIds.contains);
    final anySelected = isActive && groupIds.any(selectedIds.contains);

    final highlight = ref.watch(overdueHighlightMode);
    final overdueN = highlight ? _overdueCount() : 0;
    final isOverdue = overdueN > 0;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOverdue
            ? const BorderSide(color: AppColors.error, width: 1.5)
            : BorderSide.none,
      ),
      color: isOverdue ? AppColors.error.withAlpha(8) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ExpansionTile(
          initiallyExpanded: isOverdue,
          tilePadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
          childrenPadding: EdgeInsets.zero,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOverdue)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber, size: 13, color: AppColors.error),
                        const SizedBox(width: 4),
                        Text(
                          '검수 지연 $overdueN건',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              group.isListed
                  ? _buildListedTitle()
                  : _buildDefaultTitle(context),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (group.showGroupSelect && isActive) ...[
                GestureDetector(
                  onTap: () {
                    final notifier = ref.read(selectionProvider.notifier);
                    if (allSelected) {
                      notifier.removeAll(groupIds);
                    } else {
                      notifier.addAll(groupIds);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      allSelected
                          ? Icons.check_circle
                          : anySelected
                              ? Icons.remove_circle_outline
                              : Icons.radio_button_unchecked,
                      size: 22,
                      color: allSelected || anySelected
                          ? AppColors.primary
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
              _countBadge(),
            ],
          ),
          children: group.items
              .map((r) => ItemTile(
                    item: r.item,
                    sale: r.sale,
                    purchase: r.purchase,
                    product: r.product,
                    sourceName: r.sourceName,
                  ))
              .toList(),
        ),
      ),
    );
  }

  // ── 판매중: 상품 이미지 + 사이즈별 재고 ──
  Widget _buildListedTitle() {
    final imageUrl = group.items
        .map((r) => r.product?.imageUrl)
        .firstWhere((u) => u != null && u.isNotEmpty, orElse: () => null);

    final sizeMap = <String, int>{};
    for (final r in group.items) {
      sizeMap[r.item.sizeKr] = (sizeMap[r.item.sizeKr] ?? 0) + 1;
    }
    final sizeEntries = sizeMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          group.title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            productImage(imageUrl, size: 52),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 5,
                runSpacing: 4,
                children: sizeEntries
                    .map((e) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${e.key} ×${e.value}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
        if (group.summaryLine.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(group.summaryLine,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ],
    );
  }

  // ── 기본: 발송·검수, 정산, 매입일 등 ──
  Widget _buildDefaultTitle(BuildContext context) {
    final imageUrls = <String>[];
    final seen = <String>{};
    for (final r in group.items) {
      final url = r.product?.imageUrl;
      if (url != null && url.isNotEmpty && seen.add(url)) {
        imageUrls.add(url);
      }
      if (imageUrls.length >= 5) break;
    }
    final overflowCount = group.items
            .map((r) => r.product?.imageUrl)
            .where((u) => u != null && u.isNotEmpty)
            .toSet()
            .length -
        imageUrls.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${group.title}${group.subtitle != null ? "  ${group.subtitle}" : ""}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final url in imageUrls) ...[
                productImage(url, size: 40),
                const SizedBox(width: 4),
              ],
              if (overflowCount > 0)
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('+$overflowCount',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                ),
            ],
          ),
        ),
        if (group.isSettlement)
          _CompactSettlementSummary(items: group.items)
        else if (group.summaryLine.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(group.summaryLine,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ],
    );
  }

  Widget _countBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${group.items.length}개',
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.primary),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 압축 정산 요약
// ══════════════════════════════════════════════════

class _CompactSettlementSummary extends StatelessWidget {
  final List<ItemWithRelated> items;
  const _CompactSettlementSummary({required this.items});

  @override
  Widget build(BuildContext context) {
    int settlementTotal = 0, purchaseTotal = 0;
    double vatRefundTotal = 0;
    for (final r in items) {
      settlementTotal += r.sale?.settlementAmount ?? 0;
      purchaseTotal += r.purchase?.purchasePrice ?? 0;
      vatRefundTotal += r.purchase?.vatRefundable ?? 0;
    }
    final profit = settlementTotal - purchaseTotal + vatRefundTotal.round();
    final marginRate = purchaseTotal > 0 ? (profit / purchaseTotal * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '수익 ${profit >= 0 ? "+" : ""}${fmt.format(profit)}원 (${marginRate.toStringAsFixed(0)}%)  ·  정산 ${fmt.format(settlementTotal)}원',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: profit >= 0 ? AppColors.success : AppColors.error,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 정산 요약
// ══════════════════════════════════════════════════

class SettlementSummary extends StatelessWidget {
  final List<ItemWithRelated> items;
  const SettlementSummary({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    int sellTotal = 0, settlementTotal = 0, purchaseTotal = 0;
    double vatRefundTotal = 0;

    for (final r in items) {
      sellTotal += r.sale?.sellPrice ?? 0;
      settlementTotal += r.sale?.settlementAmount ?? 0;
      purchaseTotal += r.purchase?.purchasePrice ?? 0;
      vatRefundTotal += r.purchase?.vatRefundable ?? 0;
    }

    final profit = settlementTotal - purchaseTotal + vatRefundTotal.round();
    final marginRate =
        purchaseTotal > 0 ? (profit / purchaseTotal * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _pill('판매', sellTotal, AppColors.success),
            const SizedBox(width: 8),
            _pill('정산', settlementTotal, AppColors.primary),
          ]),
          const SizedBox(height: 2),
          Text(
            '수익 ${fmt.format(profit)}원'
            '${vatRefundTotal > 0 ? " (환급 ${fmt.format(vatRefundTotal.round())}원)" : ""}'
            ' · 마진 ${marginRate.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: profit >= 0 ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, int amount, Color color) {
    return Text('$label ${fmt.format(amount)}원',
        style: TextStyle(fontSize: 11, color: color));
  }
}
