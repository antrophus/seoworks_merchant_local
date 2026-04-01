import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import 'inventory_providers.dart';
import 'widgets/barcode_widgets.dart';
import 'widgets/batch_actions.dart';
import 'widgets/filter_chips.dart';
import 'widgets/grouped_list_view.dart';

// ══════════════════════════════════════════════════
// 메인 화면
// ══════════════════════════════════════════════════

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  bool _showMore = false;
  int? _subIndex;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(inventorySearchProvider.notifier).state = query;
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _debounce?.cancel();
    ref.read(inventorySearchProvider.notifier).state = '';
  }

  void _selectFilter(String? filterCsv) {
    ref.read(inventoryFilterProvider.notifier).state = filterCsv;
    _subIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    // 선택 모드 진입 시 키보드 숨김
    ref.listen(selectionProvider, (prev, next) {
      if (next.isNotEmpty && _searchFocus.hasFocus) {
        _searchFocus.unfocus();
      }
    });

    // 선택 불가 필터로 전환 시 선택 초기화
    ref.listen(inventoryFilterProvider, (prev, next) {
      const noSelect = {
        'SETTLED,DEFECT_SETTLED',
        'ORDER_CANCELLED,SUPPLIER_RETURN,DISPOSED,SAMPLE',
      };
      if (next != null && noSelect.contains(next)) {
        ref.read(selectionProvider.notifier).clear();
      }
    });

    final filter = ref.watch(inventoryFilterProvider);
    final searchQuery = ref.watch(inventorySearchProvider);
    final isSearching = searchQuery.isNotEmpty;
    final sortAsc = ref.watch(inventorySortAscProvider);

    String? effectiveFilter = filter;
    final currentFilterDef = findCurrentFilter(filter);
    if (_subIndex != null &&
        currentFilterDef != null &&
        currentFilterDef.statuses.length > 1) {
      effectiveFilter = currentFilterDef.statuses[_subIndex!];
    }

    final isMulti = effectiveFilter != null && effectiveFilter.contains(',');
    final searchKey = effectiveFilter != null
        ? '$searchQuery|$effectiveFilter'
        : searchQuery;
    final itemsAsync = isSearching
        ? ref.watch(searchResultProvider(searchKey))
        : (effectiveFilter == null
            ? ref.watch(itemsProvider)
            : isMulti
                ? ref.watch(multiStatusProvider(effectiveFilter))
                : ref.watch(inventoryFilteredProvider(effectiveFilter)));

    return Column(
      children: [
        // ── 셀렉트 모드 헤더 (독립 Consumer) ──
        Consumer(builder: (context, ref, _) {
          final selectedIds = ref.watch(selectionProvider);
          if (selectedIds.isEmpty) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: AppColors.primary.withAlpha(15),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () =>
                      ref.read(selectionProvider.notifier).clear(),
                  visualDensity: VisualDensity.compact,
                ),
                Text('${selectedIds.length}개 선택',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    itemsAsync.whenData((items) {
                      ref.read(selectionProvider.notifier)
                          .selectAll(items.map((i) => i.id));
                    });
                  },
                  child: const Text('전체'),
                ),
              ],
            ),
          );
        }),

        // ── 검색바 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            decoration: InputDecoration(
              hintText: 'SKU, 모델코드, 바코드 검색',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSearching)
                    IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: _clearSearch),
                  IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: '바코드 스캔',
                      onPressed: _openBarcodeScanner),
                ],
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: _onSearchChanged,
          ),
        ),

        // ── 필터 칩 + 정렬 ──
        if (!isSearching) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        InventoryFilterChip(
                            label: '전체',
                            selected: filter == null,
                            onTap: () => _selectFilter(null)),
                        const SizedBox(width: 6),
                        for (final f in mainFilters) ...[
                          InventoryFilterChip(
                            label: f.label,
                            selected: filter == f.statuses.join(',') ||
                                (f.statuses.length > 1 &&
                                    f.statuses.contains(filter)),
                            onTap: () =>
                                _selectFilter(f.statuses.join(',')),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (_showMore)
                          for (final f in moreFilters) ...[
                            InventoryFilterChip(
                              label: f.label,
                              selected: filter == f.statuses.join(','),
                              onTap: () =>
                                  _selectFilter(f.statuses.join(',')),
                            ),
                            const SizedBox(width: 6),
                          ],
                        GestureDetector(
                          onTap: () => setState(() => _showMore = !_showMore),
                          child: Chip(
                            label: Text(_showMore ? '접기' : '더보기',
                                style: const TextStyle(fontSize: 12)),
                            visualDensity: VisualDensity.compact,
                            avatar: Icon(
                                _showMore
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 개인/사업용 토글 (전체→사업용→개인용→전체)
                _PersonalFilterToggle(),
                // 정렬 토글 (최신순↔오래된순, 판매중은 재고순)
                _SortToggleButton(),
              ],
            ),
          ),

          // ── 서브 필터 탭 ──
          if (currentFilterDef?.subLabels != null)
            SubFilterTabs(
              filterDef: currentFilterDef!,
              selectedIndex: _subIndex,
              parentFilterCsv: currentFilterDef.statuses.join(','),
              onSelect: (i) => setState(() => _subIndex = i),
            ),
        ],

        const Divider(height: 1),

        // ── 아이템 목록 ──
        Expanded(
          child: itemsAsync.when(
            data: (rawItems) {
              final personalFilter = ref.watch(inventoryPersonalFilterProvider);
              final items = personalFilter == null
                  ? rawItems
                  : rawItems
                      .where((i) => i.isPersonal == personalFilter)
                      .toList();
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          isSearching
                              ? Icons.search_off
                              : Icons.inventory_2_outlined,
                          size: 64,
                          color: AppColors.textTertiary),
                      const SizedBox(height: 16),
                      Text(
                        isSearching
                            ? '검색 결과가 없습니다'
                            : (filter == null
                                ? '아이템이 없습니다'
                                : '해당 상태의 아이템이 없습니다'),
                        style:
                            const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              final sorted = List<ItemData>.from(items);
              sorted.sort((a, b) => sortAsc
                  ? (a.createdAt ?? '').compareTo(b.createdAt ?? '')
                  : (b.createdAt ?? '').compareTo(a.createdAt ?? ''));

              // 필터 있고 검색 아님 → 그룹 뷰
              if (!isSearching && filter != null) {
                return GroupedListView(
                    items: sorted, filterCsv: effectiveFilter!);
              }
              return BatchListView(items: sorted);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
          ),
        ),

        // ── 일괄 처리 하단 액션바 (독립 Consumer) ──
        Consumer(builder: (context, ref, _) {
          final selectedIds = ref.watch(selectionProvider);
          if (selectedIds.isEmpty) return const SizedBox.shrink();
          return BatchActionBar(
            selectedIds: selectedIds,
            effectiveFilter: effectiveFilter,
            onDone: () {
              final search = ref.read(inventorySearchProvider);
              final filter = ref.read(inventoryFilterProvider);

              ref.read(selectionProvider.notifier).clear();
              ref.invalidate(itemsProvider);
              ref.invalidate(itemStatusCountsProvider);

              if (search.isNotEmpty) {
                // 현재 검색 키만 invalidate
                final key =
                    filter != null ? '$search|$filter' : search;
                ref.invalidate(searchResultProvider(key));
                // _subIndex 활성 시 하위 필터별 검색 결과도 invalidate
                if (filter != null && filter.contains(',')) {
                  for (final s in filter.split(',')) {
                    ref.invalidate(searchResultProvider('$search|$s'));
                  }
                }
              } else if (filter != null) {
                if (filter.contains(',')) {
                  ref.invalidate(multiStatusProvider(filter));
                  // _subIndex 활성 시 단일 상태 필터도 invalidate
                  for (final s in filter.split(',')) {
                    ref.invalidate(inventoryFilteredProvider(s));
                  }
                } else {
                  ref.invalidate(inventoryFilteredProvider(filter));
                }
              }
            },
          );
        }),
      ],
    );
  }

  // ── 바코드 스캐너 ──

  Future<void> _openBarcodeScanner() async {
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    String? barcode;
    if (isMobile) {
      barcode = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const BarcodeScanSheet(),
      );
    } else {
      final ctrl = TextEditingController();
      barcode = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('바코드 입력'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: '바코드 번호', border: OutlineInputBorder()),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('검색')),
          ],
        ),
      );
    }

    if (barcode != null && barcode.isNotEmpty && mounted) {
      final filter = ref.read(inventoryFilterProvider);
      final currentFilter = findCurrentFilter(filter);
      final statuses = currentFilter?.statuses;

      final item = await ref.read(itemDaoProvider).getByBarcode(barcode);
      if (!mounted) return;

      if (item != null && statuses != null &&
          !statuses.contains(item.currentStatus)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            '바코드 $barcode → 현재 필터(${currentFilter!.label})에 해당하지 않는 상태입니다')),
        );
        return;
      }

      if (item != null) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (ctx, sc) =>
                BarcodeResultSheet(barcode: barcode!, item: item, scrollController: sc),
          ),
        );
        if (mounted) {
          final product =
              await ref.read(masterDaoProvider).getProductById(item.productId);
          if (product != null && mounted) {
            _searchCtrl.text = product.modelCode;
            _debounce?.cancel();
            ref.read(inventorySearchProvider.notifier).state = product.modelCode;
          }
        }
      } else {
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.warning_amber,
                color: AppColors.warning, size: 40),
            title: const Text('없는 상품'),
            content: Text('바코드 $barcode 미등록.\n입고 등록하시겠습니까?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('닫기')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('입고 등록')),
            ],
          ),
        );
        if (go == true && mounted) context.push('/register');
      }
    }
  }
}

// ── 개인/사업용 토글 (전체→사업용→개인용→전체) ──
class _PersonalFilterToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pf = ref.watch(inventoryPersonalFilterProvider);
    final label = pf == null ? '전체' : pf ? '소장품' : '사업용';
    final icon = pf == null
        ? Icons.people_outline
        : pf
            ? Icons.person
            : Icons.store;

    return IconButton(
      icon: Icon(icon, size: 20, color: pf != null ? AppColors.primary : null),
      tooltip: label,
      onPressed: () {
        // null → false → true → null
        final next = pf == null ? false : pf ? null : true;
        ref.read(inventoryPersonalFilterProvider.notifier).state = next;
      },
    );
  }
}

// ── 정렬 토글 (최신순↔오래된순) ──
class _SortToggleButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortAsc = ref.watch(inventorySortAscProvider);

    return IconButton(
      icon: Icon(
        sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
        size: 20,
      ),
      tooltip: sortAsc ? '오래된 순' : '최신 순',
      onPressed: () {
        ref.read(inventorySortAscProvider.notifier).state = !sortAsc;
      },
    );
  }
}
