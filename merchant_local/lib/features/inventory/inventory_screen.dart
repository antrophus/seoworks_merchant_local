import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import 'status_actions.dart';

/// 재고 상태 필터
final inventoryFilterProvider = StateProvider<String?>((ref) => null);

/// 검색어 Provider
final inventorySearchProvider = StateProvider<String>((ref) => '');

/// 검색 결과 Provider
final inventorySearchResultProvider =
    FutureProvider.family<List<ItemData>, String>((ref, query) {
  if (query.trim().isEmpty) return Future.value([]);
  return ref.watch(itemDaoProvider).search(query.trim());
});

/// 상태별 필터 Provider
final inventoryFilteredProvider =
    StreamProvider.family<List<ItemData>, String>((ref, status) {
  return ref.watch(itemDaoProvider).watchByStatus(status);
});

/// 상태 그룹 정의
const _statusGroups = <String, List<String>>{
  '활성재고': [
    'ORDER_PLACED',
    'OFFICE_STOCK',
    'OUTGOING',
    'IN_INSPECTION',
    'LISTED',
  ],
  '판매/정산': ['SOLD', 'SETTLED', 'DEFECT_SOLD', 'DEFECT_SETTLED'],
  '불량/수선': ['DEFECT_FOR_SALE', 'DEFECT_HELD', 'RETURNING', 'REPAIRING'],
  '기타': ['ORDER_CANCELLED', 'SUPPLIER_RETURN', 'DISPOSED', 'SAMPLE'],
};

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

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(inventorySearchProvider.notifier).state = query;
  }

  void _clearSearch() {
    _searchCtrl.clear();
    ref.read(inventorySearchProvider.notifier).state = '';
  }

  Future<void> _openBarcodeScanner() async {
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (isMobile) {
      final barcode = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => const _BarcodeScanSheet(),
      );
      if (barcode != null && barcode.isNotEmpty && mounted) {
        _showBarcodeResult(barcode);
      }
    } else {
      // 데스크톱: 바코드 직접 입력
      final ctrl = TextEditingController();
      final barcode = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('바코드 입력'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '바코드 번호',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('검색')),
          ],
        ),
      );
      if (barcode != null && barcode.isNotEmpty && mounted) {
        _showBarcodeResult(barcode);
      }
    }
  }

  Future<void> _showBarcodeResult(String barcode) async {
    // 1. 바코드로 아이템 직접 조회
    final item = await ref.read(itemDaoProvider).getByBarcode(barcode);

    if (item != null) {
      // 같은 productId의 모든 아이템 (사이즈별 재고)
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (ctx, scrollCtrl) => _BarcodeResultSheet(
            barcode: barcode,
            item: item,
            scrollController: scrollCtrl,
          ),
        ),
      );
    } else {
      // 미등록 바코드
      if (!mounted) return;
      final goRegister = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 40),
          title: const Text('없는 상품'),
          content: Text('바코드 $barcode에 해당하는\n재고·구매·판매 이력이 없습니다.\n\n새 상품으로 입고 등록하시겠습니까?'),
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
      if (goRegister == true && mounted) {
        context.push('/register');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(inventoryFilterProvider);
    final searchQuery = ref.watch(inventorySearchProvider);
    final isSearching = searchQuery.isNotEmpty;

    // 검색 중이면 검색 결과, 아니면 필터 결과
    final itemsAsync = isSearching
        ? ref.watch(inventorySearchResultProvider(searchQuery))
        : (filter == null
            ? ref.watch(itemsProvider)
            : ref.watch(inventoryFilteredProvider(filter)));

    return Column(
      children: [
        // 검색바
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'SKU, 모델코드, 바코드 검색',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSearching)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: _clearSearch,
                    ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: '바코드 스캔',
                    onPressed: _openBarcodeScanner,
                  ),
                ],
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: _onSearchChanged,
          ),
        ),

        // 상태 필터 칩 (검색 중이 아닐 때만)
        if (!isSearching)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: '전체',
                  selected: filter == null,
                  onTap: () =>
                      ref.read(inventoryFilterProvider.notifier).state = null,
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: '사무실재고',
                  selected: filter == 'OFFICE_STOCK',
                  onTap: () => ref
                      .read(inventoryFilterProvider.notifier)
                      .state = 'OFFICE_STOCK',
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: '주문완료',
                  selected: filter == 'ORDER_PLACED',
                  onTap: () => ref
                      .read(inventoryFilterProvider.notifier)
                      .state = 'ORDER_PLACED',
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: '발송중',
                  selected: filter == 'OUTGOING',
                  onTap: () => ref
                      .read(inventoryFilterProvider.notifier)
                      .state = 'OUTGOING',
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: '검수중',
                  selected: filter == 'IN_INSPECTION',
                  onTap: () => ref
                      .read(inventoryFilterProvider.notifier)
                      .state = 'IN_INSPECTION',
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: '리스팅',
                  selected: filter == 'LISTED',
                  onTap: () => ref
                      .read(inventoryFilterProvider.notifier)
                      .state = 'LISTED',
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: '판매완료',
                  selected: filter == 'SOLD',
                  onTap: () =>
                      ref.read(inventoryFilterProvider.notifier).state = 'SOLD',
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: '정산완료',
                  selected: filter == 'SETTLED',
                  onTap: () => ref
                      .read(inventoryFilterProvider.notifier)
                      .state = 'SETTLED',
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: '불량보류',
                  selected: filter == 'DEFECT_HELD',
                  onTap: () => ref
                      .read(inventoryFilterProvider.notifier)
                      .state = 'DEFECT_HELD',
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: '수선중',
                  selected: filter == 'REPAIRING',
                  onTap: () => ref
                      .read(inventoryFilterProvider.notifier)
                      .state = 'REPAIRING',
                ),
              ],
            ),
          ),
        const Divider(height: 1),

        // 아이템 목록
        Expanded(
          child: itemsAsync.when(
            data: (items) {
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
                          color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        isSearching
                            ? '검색 결과가 없습니다'
                            : (filter == null
                                ? '아이템이 없습니다'
                                : '해당 상태의 아이템이 없습니다'),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _ItemTile(item: item);
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

// ══════════════════════════════════════════════════
// 바코드 스캔 바텀시트 (카메라)
// ══════════════════════════════════════════════════

class _BarcodeScanSheet extends StatefulWidget {
  const _BarcodeScanSheet();

  @override
  State<_BarcodeScanSheet> createState() => _BarcodeScanSheetState();
}

class _BarcodeScanSheetState extends State<_BarcodeScanSheet> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('바코드 스캔',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.flash_on, size: 20),
                  onPressed: () => _controller.toggleTorch(),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    if (_scanned) return;
                    final code = capture.barcodes.firstOrNull?.rawValue;
                    if (code != null && code.isNotEmpty) {
                      _scanned = true;
                      Navigator.pop(context, code);
                    }
                  },
                ),
                Center(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white54, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 바코드 검색 결과 시트 (사이즈별 재고 + 구매/판매 이력)
// ══════════════════════════════════════════════════

class _BarcodeResultSheet extends ConsumerWidget {
  final String barcode;
  final ItemData item;
  final ScrollController scrollController;

  const _BarcodeResultSheet({
    required this.barcode,
    required this.item,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(_productProvider(item.productId));
    final siblingsAsync = ref.watch(_siblingItemsProvider(item.productId));
    final fmt = NumberFormat('#,###');

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          // 핸들
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 상품 정보 헤더
          productAsync.when(
            data: (product) {
              if (product == null) return const SizedBox.shrink();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if (product.imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            product.imageUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox(width: 56, height: 56),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.modelName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(product.modelCode,
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 13)),
                            Text('바코드: $barcode',
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),

          // 사이즈별 재고 + 구매/판매 정보
          Text('사이즈별 현황',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          siblingsAsync.when(
            data: (siblings) {
              if (siblings.isEmpty) {
                return const Text('아이템이 없습니다');
              }

              // 사이즈별 그룹핑
              final grouped = <String, List<ItemData>>{};
              for (final s in siblings) {
                grouped.putIfAbsent(s.sizeKr, () => []).add(s);
              }

              return Column(
                children: grouped.entries.map((e) {
                  final size = e.key;
                  final items = e.value;
                  final activeCount = items
                      .where((i) => !{
                            'SETTLED',
                            'DEFECT_SETTLED',
                            'ORDER_CANCELLED',
                            'SUPPLIER_RETURN',
                            'DISPOSED'
                          }.contains(i.currentStatus))
                      .length;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: activeCount > 0
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                        child: Text('$activeCount',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: activeCount > 0
                                    ? Colors.green.shade800
                                    : Colors.grey)),
                      ),
                      title: Text('사이즈 $size',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('총 ${items.length}건 (활성 $activeCount건)',
                          style: const TextStyle(fontSize: 12)),
                      children: items.map((si) {
                        return _SizeItemRow(item: si, fmt: fmt);
                      }).toList(),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('오류: $e'),
          ),

          const SizedBox(height: 12),
          // 바로가기 버튼
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/item/${item.id}');
                  },
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('상세 보기'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/register');
                  },
                  icon: const Icon(Icons.add_box, size: 18),
                  label: const Text('추가 입고'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 사이즈 내 개별 아이템 행 (구매/판매 정보 포함)
class _SizeItemRow extends ConsumerWidget {
  final ItemData item;
  final NumberFormat fmt;

  const _SizeItemRow({required this.item, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchaseAsync = ref.watch(_purchaseProvider(item.id));
    final saleAsync = ref.watch(_saleProvider(item.id));
    final statusLabel = _statusLabels[item.currentStatus] ?? item.currentStatus;
    final statusClr = _statusColor(item.currentStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(item.sku,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: statusClr.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusClr)),
              ),
            ],
          ),
          purchaseAsync.when(
            data: (p) {
              if (p == null) return const SizedBox.shrink();
              return Text(
                '매입: ${p.purchasePrice != null ? "${fmt.format(p.purchasePrice)}원" : "-"}'
                '  ·  ${p.purchaseDate ?? "-"}'
                '  ·  ${_paymentLabel(p.paymentMethod)}',
                style: TextStyle(fontSize: 11, color: Colors.blue.shade400),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          saleAsync.when(
            data: (s) {
              if (s == null) return const SizedBox.shrink();
              return Text(
                '판매: ${s.sellPrice != null ? "${fmt.format(s.sellPrice)}원" : (s.listedPrice != null ? "등록가 ${fmt.format(s.listedPrice)}원" : "-")}'
                '  ·  ${s.platform}'
                '${s.saleDate != null ? "  ·  ${s.saleDate}" : ""}',
                style: TextStyle(fontSize: 11, color: Colors.green.shade400),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const Divider(height: 8),
        ],
      ),
    );
  }

  String _paymentLabel(String m) => switch (m) {
        'CORPORATE_CARD' => '법인카드',
        'PERSONAL_CARD' => '개인카드',
        'CASH' => '현금',
        'TRANSFER' => '계좌이체',
        _ => m,
      };
}

/// 같은 상품의 전체 아이템 (사이즈별)
final _siblingItemsProvider =
    FutureProvider.family<List<ItemData>, String>((ref, productId) {
  return ref.watch(itemDaoProvider).getAllByProductId(productId);
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
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ItemTile extends ConsumerWidget {
  final ItemData item;
  const _ItemTile({required this.item});

  static const _defectStatuses = {
    'REPAIRING', 'RETURNING', 'DEFECT_FOR_SALE', 'DEFECT_HELD',
    'DEFECT_SOLD', 'DEFECT_SETTLED', 'SUPPLIER_RETURN',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusLabel = _statusLabels[item.currentStatus] ?? item.currentStatus;
    final statusClr = _statusColor(item.currentStatus);
    final showDefectInfo = _defectStatuses.contains(item.currentStatus);

    // 정보 로드
    final purchaseAsync = ref.watch(_purchaseProvider(item.id));
    final saleAsync = ref.watch(_saleProvider(item.id));
    final productAsync = ref.watch(_productProvider(item.productId));

    // 수선/반송 사유 (해당 상태일 때만)
    final inspectionAsync =
        showDefectInfo ? ref.watch(_latestInspectionProvider(item.id)) : null;
    final repairAsync = item.currentStatus == 'REPAIRING'
        ? ref.watch(_latestRepairProvider(item.id))
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
      onTap: () => context.push('/item/${item.id}'),
      onLongPress: () async {
        final result = await showStatusActionSheet(
          context: context,
          ref: ref,
          item: item,
        );
        if (result == true) {
          ref.invalidate(itemsProvider);
          ref.invalidate(itemStatusCountsProvider);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상품 이미지
            productAsync.when(
              data: (product) {
                final url = product?.imageUrl;
                if (url == null) {
                  return const SizedBox(
                    width: 56, height: 56,
                    child: Icon(Icons.inventory_2, size: 32, color: Colors.grey),
                  );
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url, width: 56, height: 56, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      width: 56, height: 56,
                      child: Icon(Icons.broken_image, size: 32, color: Colors.grey),
                    ),
                  ),
                );
              },
              loading: () => const SizedBox(width: 56, height: 56),
              error: (_, __) => const SizedBox(width: 56, height: 56),
            ),
            const SizedBox(width: 12),

            // 텍스트 정보
            Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: SKU + 상태 배지 + 상태변경 버튼
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.sku,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusClr.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusClr,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (statusActions.containsKey(item.currentStatus))
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      icon: Icon(Icons.swap_horiz, size: 16, color: statusClr),
                      padding: EdgeInsets.zero,
                      tooltip: '상태 변경',
                      onPressed: () async {
                        final result = await showStatusActionSheet(
                          context: context,
                          ref: ref,
                          item: item,
                        );
                        if (result == true) {
                          ref.invalidate(itemsProvider);
                          ref.invalidate(itemStatusCountsProvider);
                        }
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // 사이즈
            Text(
              '사이즈: ${item.sizeKr}${item.sizeEu != null ? ' / EU ${item.sizeEu}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            // 매입/판매 정보
            purchaseAsync.when(
              data: (purchase) {
                if (purchase == null) return const SizedBox.shrink();
                final priceStr = purchase.purchasePrice != null
                    ? NumberFormat('#,###').format(purchase.purchasePrice)
                    : '-';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '매입: ${priceStr}원  ·  ${purchase.paymentMethod}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.blue.shade300),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            saleAsync.when(
              data: (sale) {
                if (sale == null) return const SizedBox.shrink();
                final sellStr = sale.sellPrice != null
                    ? NumberFormat('#,###').format(sale.sellPrice)
                    : '-';
                final settlStr = sale.settlementAmount != null
                    ? NumberFormat('#,###').format(sale.settlementAmount)
                    : '-';
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '판매: ${sellStr}원 → 정산: ${settlStr}원  ·  ${sale.platform}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.green.shade300),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // ── 검수 반려 사유 (불량/반송/수선 상태) ──
            if (showDefectInfo && inspectionAsync != null)
              inspectionAsync.when(
                data: (inspection) {
                  if (inspection == null) return const SizedBox.shrink();
                  return _DefectInfoChip(inspection: inspection);
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

            // ── 수선 메모 (수선중) ──
            if (repairAsync != null)
              repairAsync.when(
                data: (repair) {
                  if (repair == null) return const SizedBox.shrink();
                  return _RepairInfoChip(repair: repair);
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

            // 불량 메모
            if (item.defectNote != null && item.defectNote!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '불량: ${item.defectNote}',
                  style: TextStyle(color: Colors.red.shade300, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // 개인용
            if (item.isPersonal)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '개인용',
                  style: TextStyle(
                      color: Colors.pink.shade300, fontSize: 11),
                ),
              ),
          ],
        )),  // Column + Expanded
          ],
        ),  // Row
      ),  // Padding
      ),  // InkWell
    );  // Card
  }
}

/// 검수 반려 사유 칩 (리스트 타일 내)
class _DefectInfoChip extends StatelessWidget {
  final InspectionRejectionData inspection;
  const _DefectInfoChip({required this.inspection});

  @override
  Widget build(BuildContext context) {
    final defectLabel = switch (inspection.defectType) {
      'DEFECT_SALE' => '불량판매',
      'DEFECT_HELD' => '불량보류',
      'DEFECT_RETURN' => '반송',
      _ => inspection.defectType ?? '검수반려',
    };

    // 사진 URL 파싱 (JSON 배열 문자열)
    final photoUrls = _parsePhotoUrls(inspection.photoUrls);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, size: 14, color: Colors.amber.shade700),
                const SizedBox(width: 4),
                Text(
                  '검수 반려 #${inspection.returnSeq} ($defectLabel)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade800,
                  ),
                ),
                if (inspection.discountAmount != null) ...[
                  const Spacer(),
                  Text(
                    '-${NumberFormat('#,###').format(inspection.discountAmount)}원',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade600,
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
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            // 사진 썸네일
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
                          color: Colors.grey.shade200,
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
    // JSON 배열: ["url1", "url2"] 또는 comma-separated
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

/// 수선 정보 칩 (리스트 타일 내)
class _RepairInfoChip extends StatelessWidget {
  final RepairData repair;
  const _RepairInfoChip({required this.repair});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.brown.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.brown.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, size: 14, color: Colors.brown.shade700),
                const SizedBox(width: 4),
                Text(
                  '수선중 (${repair.startedAt}~)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.brown.shade800,
                  ),
                ),
                if (repair.repairCost != null) ...[
                  const Spacer(),
                  Text(
                    '${NumberFormat('#,###').format(repair.repairCost)}원',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.brown.shade600,
                    ),
                  ),
                ],
              ],
            ),
            if (repair.repairNote != null && repair.repairNote!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  repair.repairNote!,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 아이템별 매입 정보 Provider
final _purchaseProvider =
    FutureProvider.family<PurchaseData?, String>((ref, itemId) {
  return ref.watch(purchaseDaoProvider).getByItemId(itemId);
});

/// 아이템별 판매 정보 Provider
final _saleProvider =
    FutureProvider.family<SaleData?, String>((ref, itemId) {
  return ref.watch(saleDaoProvider).getByItemId(itemId);
});

/// 아이템별 상품(이미지) 정보 Provider
final _productProvider =
    FutureProvider.family<Product?, String>((ref, productId) {
  return ref.watch(masterDaoProvider).getProductById(productId);
});

/// 아이템별 최신 검수반려 Provider
final _latestInspectionProvider =
    FutureProvider.family<InspectionRejectionData?, String>((ref, itemId) async {
  final list = await ref.watch(subRecordDaoProvider).getInspectionRejections(itemId);
  return list.isNotEmpty ? list.last : null;
});

/// 아이템별 최신 수선 Provider
final _latestRepairProvider =
    FutureProvider.family<RepairData?, String>((ref, itemId) async {
  final list = await ref.watch(subRecordDaoProvider).getRepairs(itemId);
  return list.isNotEmpty ? list.first : null;
});
