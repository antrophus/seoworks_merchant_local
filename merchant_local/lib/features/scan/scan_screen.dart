import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'dart:math' show min, max;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:drift/drift.dart' show Value;
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/services/llm_router.dart';
import '../inventory/status_actions.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스캔'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: '바코드'),
            Tab(icon: Icon(Icons.image_search), text: '이미지 인식'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _BarcodeScanTab(),
          _ImageRecognitionTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 바코드 스캔 탭
// ══════════════════════════════════════════════════

class _BarcodeScanTab extends ConsumerStatefulWidget {
  const _BarcodeScanTab();

  @override
  ConsumerState<_BarcodeScanTab> createState() => _BarcodeScanTabState();
}

class _BarcodeScanTabState extends ConsumerState<_BarcodeScanTab> {
  MobileScannerController? _scannerCtrl;
  String? _lastBarcode;
  bool _searching = false;
  bool _showingSheet = false;

  // 연속스캔 모드
  bool _continuousMode = false;
  final List<ItemData> _bucket = [];
  final Set<String> _bucketBarcodes = {};

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (_isMobile) {
      _scannerCtrl = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
    }
  }

  @override
  void dispose() {
    _scannerCtrl?.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(String barcode) async {
    if (_searching || _showingSheet) return;

    if (_continuousMode) {
      // 연속스캔: 중복 방지 후 장바구니에 추가
      if (_bucketBarcodes.contains(barcode)) return;
      setState(() => _searching = true);
      final item = await ref.read(itemDaoProvider).getByBarcode(barcode);
      if (mounted) {
        setState(() {
          _searching = false;
          if (item != null) {
            _bucket.add(item);
            _bucketBarcodes.add(barcode);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('바코드 $barcode — 미등록 상품'),
                  duration: const Duration(seconds: 1)),
            );
          }
        });
      }
      return;
    }

    // 단일 스캔 모드
    if (barcode == _lastBarcode) return;
    _lastBarcode = barcode;
    setState(() => _searching = true);

    final item = await ref.read(itemDaoProvider).getByBarcode(barcode);
    if (!mounted) return;
    setState(() => _searching = false);

    _scannerCtrl?.stop();
    _showingSheet = true;
    await _showResultSheet(barcode, item);
  }

  Future<void> _showResultSheet(String barcode, ItemData? item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => item != null
          ? _BarcodeFoundSheet(
              barcode: barcode,
              item: item,
            )
          : _BarcodeNotFoundSheet(barcode: barcode),
    );

    _showingSheet = false;
    _lastBarcode = null;

    if (action == 'detail' && mounted) {
      await context.push('/item/${item!.id}');
      if (mounted) _scannerCtrl?.start();
    } else if (action == 'register' && mounted) {
      await context.push('/register');
      if (mounted) _scannerCtrl?.start();
    } else if (action == 'link' && mounted) {
      final linked = await _showBarcodeLinkSheet(barcode);
      if (mounted) {
        if (linked == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('바코드가 연결되었습니다')),
          );
        }
        _scannerCtrl?.start();
      }
    } else {
      // 다시 스캔 또는 시트 닫기 → 스캐너 재개
      _scannerCtrl?.start();
    }
  }

  Future<bool?> _showBarcodeLinkSheet(String barcode) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BarcodeLinkSheet(barcode: barcode),
    );
  }

  void _clearBucket() {
    setState(() {
      _bucket.clear();
      _bucketBarcodes.clear();
    });
  }

  Future<void> _processBucket() async {
    if (_bucket.isEmpty) return;

    // 같은 상태인지 확인
    final statuses = _bucket.map((i) => i.currentStatus).toSet();
    if (statuses.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('같은 상태의 아이템만 일괄 처리할 수 있습니다')),
      );
      return;
    }

    final result = await showStatusActionSheet(
      context: context,
      ref: ref,
      item: _bucket.first,
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_bucket.length}건 처리 완료')),
      );
      _clearBucket();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMobile) {
      // Windows/데스크톱: 카메라 없음 → 수동 바코드 입력
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.desktop_windows, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('데스크톱에서는 카메라 스캔을 사용할 수 없습니다.',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: '바코드 직접 입력',
                  prefixIcon: Icon(Icons.keyboard),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) _onBarcodeDetected(v.trim());
                },
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // 모드 토글 바
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('단일'),
                selected: !_continuousMode,
                onSelected: (_) => setState(() => _continuousMode = false),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('연속 스캔'),
                selected: _continuousMode,
                onSelected: (_) => setState(() => _continuousMode = true),
                visualDensity: VisualDensity.compact,
                avatar: _continuousMode
                    ? null
                    : const Icon(Icons.playlist_add, size: 16),
              ),
              const Spacer(),
              if (_continuousMode && _bucket.isNotEmpty) ...[
                Text('${_bucket.length}건',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: _clearBucket,
                  tooltip: '비우기',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
        ),

        // 카메라 뷰
        Expanded(
          flex: _continuousMode && _bucket.isNotEmpty ? 2 : 3,
          child: Stack(
            children: [
              MobileScanner(
                controller: _scannerCtrl!,
                onDetect: (capture) {
                  final barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final code = barcodes.first.rawValue;
                    if (code != null) _onBarcodeDetected(code);
                  }
                },
              ),
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white54, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              // 스캔 중 인디케이터
              if (_searching)
                const Center(child: CircularProgressIndicator(color: Colors.white)),
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.flash_on, color: Colors.white),
                      onPressed: () => _scannerCtrl!.toggleTorch(),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.cameraswitch, color: Colors.white),
                      onPressed: () => _scannerCtrl!.switchCamera(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 연속스캔 장바구니
        if (_continuousMode)
          Expanded(
            flex: 2,
            child: _buildBucket(),
          ),
      ],
    );
  }

  Widget _buildBucket() {
    if (_bucket.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_add, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            const Text('바코드를 연속으로 스캔하세요',
                style: TextStyle(color: Colors.grey)),
            const Text('스캔할 때마다 목록에 추가됩니다',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: _bucket.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final item = _bucket[i];
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.grey.shade200,
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                title: Text(item.sku,
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                    'KR ${item.sizeKr} · ${item.currentStatus}',
                    style: const TextStyle(fontSize: 11)),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  onPressed: () {
                    setState(() {
                      _bucketBarcodes.remove(item.barcode);
                      _bucket.removeAt(i);
                    });
                  },
                ),
              );
            },
          ),
        ),
        // 일괄 처리 버튼
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _processBucket,
              icon: const Icon(Icons.swap_vert_rounded, size: 18),
              label: Text('${_bucket.length}건 일괄 상태 변경'),
            ),
          ),
        ),
      ],
    );
  }
}

class _BarcodeFoundSheet extends ConsumerWidget {
  final String barcode;
  final ItemData item;

  const _BarcodeFoundSheet({
    required this.barcode,
    required this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(_productForScanProvider(item.productId));
    final stockListAsync = ref.watch(_modelSizeStockProvider(
        (productId: item.productId, sizeKr: item.sizeKr)));
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding:
                  EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더: 모델명 + 사이즈
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: productAsync.when(
                          data: (p) => p != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.modelName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 2),
                                    Text(
                                        '${p.modelCode}  ·  KR ${item.sizeKr}${item.sizeEu != null ? " / EU ${item.sizeEu}" : ""}',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600)),
                                  ],
                                )
                              : Text('KR ${item.sizeKr}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                          loading: () => Text('KR ${item.sizeKr}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  stockListAsync.when(
                    loading: () => const Center(
                        child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    )),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (list) {
                      // 판매 가능 재고 (리스팅, 포이즌보관만)
                      const activeStatuses = {'LISTED', 'POIZON_STORAGE'};
                      final activeGroups = <String, int>{};
                      for (final info in list) {
                        if (activeStatuses.contains(info.item.currentStatus)) {
                          activeGroups[info.item.currentStatus] =
                              (activeGroups[info.item.currentStatus] ?? 0) + 1;
                        }
                      }
                      final activeTotal =
                          activeGroups.values.fold(0, (a, b) => a + b);

                      // 가격 목록 (전체)
                      final prices = list
                          .where((i) => i.purchasePrice != null)
                          .map((i) => i.purchasePrice!)
                          .toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 재고 현황 (판매 가능 상태만)
                          Row(
                            children: [
                              const Text('재고 현황',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Text(
                                activeTotal > 0
                                    ? '판매 가능 $activeTotal개'
                                    : '판매 가능 없음',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: activeTotal > 0
                                        ? Colors.black87
                                        : Colors.grey.shade500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          activeTotal > 0
                              ? Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: activeGroups.entries.map((e) {
                                    final style = _statusBadgeStyle(e.key);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: style.bg,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border:
                                            Border.all(color: style.border),
                                      ),
                                      child: Text(
                                        '${_statusLabel(e.key)} ${e.value}개',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: style.text,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    );
                                  }).toList(),
                                )
                              : Text('리스팅 또는 포이즌보관 중인 재고가 없습니다.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500)),

                          if (prices.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            // 가격 요약
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _PriceSummaryCell(
                                      label: '최저',
                                      price: prices.reduce(min)),
                                  Container(
                                      width: 1,
                                      height: 28,
                                      color: Colors.grey.shade300),
                                  _PriceSummaryCell(
                                      label: '평균',
                                      price: (prices.reduce((a, b) => a + b) /
                                              prices.length)
                                          .round()),
                                  Container(
                                      width: 1,
                                      height: 28,
                                      color: Colors.grey.shade300),
                                  _PriceSummaryCell(
                                      label: '최고',
                                      price: prices.reduce(max)),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 8),
                          // 구매 이력 (접기/펼치기)
                          Theme(
                            data: Theme.of(context)
                                .copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              leading: const Icon(Icons.history, size: 20),
                              title: Text('구매 이력 ${list.length}건',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              children: list
                                  .map((info) =>
                                      _PurchaseHistoryTile(info: info))
                                  .toList(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 12),
                  // 액션 버튼
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, 'rescan'),
                          child: const Text('다시 스캔'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, 'detail'),
                          child: const Text('상세 보기'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceSummaryCell extends StatelessWidget {
  final String label;
  final int price;

  const _PriceSummaryCell({required this.label, required this.price});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style:
                TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text('${NumberFormat('#,###').format(price)}원',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _PurchaseHistoryTile extends StatelessWidget {
  final _ItemPurchaseInfo info;

  const _PurchaseHistoryTile({required this.info});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.sourceName ?? '구매처 미기록',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  info.purchaseDate ?? '-',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (info.purchasePrice != null)
            Text(
              '${NumberFormat('#,###').format(info.purchasePrice)}원',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          const SizedBox(width: 8),
          Builder(builder: (_) {
            final style = _statusBadgeStyle(info.item.currentStatus);
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: style.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: style.border),
              ),
              child: Text(
                _statusLabel(info.item.currentStatus),
                style: TextStyle(
                    fontSize: 10,
                    color: style.text,
                    fontWeight: FontWeight.w500),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _BarcodeNotFoundSheet extends StatelessWidget {
  final String barcode;

  const _BarcodeNotFoundSheet({required this.barcode});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text('바코드 미등록: $barcode',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.orange.shade800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('등록된 아이템이 없습니다.'),
          const SizedBox(height: 20),
          // 바코드 연결 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'link'),
              icon: const Icon(Icons.link, size: 18),
              label: const Text('기존 재고에 바코드 연결'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, 'rescan'),
                  child: const Text('다시 스캔'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, 'register'),
                  child: const Text('입고 등록'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 바코드 연결 시트
// ══════════════════════════════════════════════════

class _BarcodeLinkSheet extends ConsumerStatefulWidget {
  final String barcode;
  const _BarcodeLinkSheet({required this.barcode});

  @override
  ConsumerState<_BarcodeLinkSheet> createState() => _BarcodeLinkSheetState();
}

class _BarcodeLinkSheetState extends ConsumerState<_BarcodeLinkSheet> {
  final _searchCtrl = TextEditingController();
  List<ItemData> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _searched = true;
    });
    final items =
        await ref.read(itemDaoProvider).searchWithoutBarcode(query.trim());
    if (mounted) {
      setState(() {
        _results = items;
        _loading = false;
      });
    }
  }

  Future<void> _linkBarcode(ItemData item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('바코드 연결'),
        content: Text(
          '${item.sku} (KR ${item.sizeKr})에\n'
          '바코드 ${widget.barcode}를 연결하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('연결'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    await ref.read(itemDaoProvider).updateItem(
          item.id,
          ItemsCompanion(
            barcode: Value(widget.barcode),
            updatedAt: Value(DateTime.now().toIso8601String()),
          ),
        );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final keyboardPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomPad + keyboardPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 헤더
          Row(
            children: [
              const Icon(Icons.link, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text('바코드 연결: ${widget.barcode}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('바코드가 없는 재고를 검색하여 연결합니다.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 12),
          // 검색 입력
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'SKU, 모델코드, 모델명 검색',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, size: 20),
                onPressed: () => _search(_searchCtrl.text),
              ),
            ),
            onSubmitted: _search,
          ),
          const SizedBox(height: 12),
          // 결과
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else if (_searched && _results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('바코드 없는 아이템을 찾을 수 없습니다.',
                  style: TextStyle(color: Colors.grey.shade500)),
            )
          else if (_results.isNotEmpty)
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final item = _results[i];
                  final productAsync =
                      ref.watch(_productForScanProvider(item.productId));
                  return ListTile(
                    dense: true,
                    title: Text(item.sku,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KR ${item.sizeKr} · ${_statusLabel(item.currentStatus)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        productAsync.when(
                          data: (p) => p != null
                              ? Text(p.modelName,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600))
                              : const SizedBox.shrink(),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: () => _linkBarcode(item),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('연결', style: TextStyle(fontSize: 13)),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// AI 이미지 인식 탭
// ══════════════════════════════════════════════════

class _ImageRecognitionTab extends ConsumerStatefulWidget {
  const _ImageRecognitionTab();

  @override
  ConsumerState<_ImageRecognitionTab> createState() =>
      _ImageRecognitionTabState();
}

class _ImageRecognitionTabState extends ConsumerState<_ImageRecognitionTab> {
  final _picker = ImagePicker();
  Uint8List? _imageBytes;
  bool _analyzing = false;
  ProductRecognitionResult? _result;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await File(picked.path).readAsBytes();

      // 리사이즈 (max 1024px)
      final resized = _resizeImage(bytes);

      setState(() {
        _imageBytes = resized;
        _result = null;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '이미지 로드 실패: $e');
    }
  }

  Uint8List _resizeImage(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    if (decoded.width <= 1024 && decoded.height <= 1024) {
      return img.encodeJpg(decoded, quality: 85);
    }

    final resized = img.copyResize(
      decoded,
      width: decoded.width > decoded.height ? 1024 : null,
      height: decoded.height >= decoded.width ? 1024 : null,
      interpolation: img.Interpolation.linear,
    );
    return img.encodeJpg(resized, quality: 85);
  }

  Future<void> _analyze() async {
    if (_imageBytes == null) return;

    setState(() {
      _analyzing = true;
      _error = null;
    });

    try {
      final result = await LlmRouter().recognizeProduct(_imageBytes!);
      if (mounted) setState(() => _result = result);

      // 바코드 발견 시 자동 조회
      if (result.barcode != null && result.barcode!.isNotEmpty) {
        final item =
            await ref.read(itemDaoProvider).getByBarcode(result.barcode!);
        if (item != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('바코드 ${result.barcode} → ${item.sku} 발견'),
              action: SnackBarAction(
                label: '상세',
                onPressed: () => context.push('/item/${item.id}'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _reset() {
    setState(() {
      _imageBytes = null;
      _result = null;
      _error = null;
    });
  }

  void _goToRegister(ProductRecognitionResult edited) {
    final params = <String, String>{};
    if (edited.brand != null && edited.brand!.isNotEmpty) params['brand'] = edited.brand!;
    if (edited.modelCode != null && edited.modelCode!.isNotEmpty) params['modelCode'] = edited.modelCode!;
    if (edited.modelName != null && edited.modelName!.isNotEmpty) params['modelName'] = edited.modelName!;
    if (edited.sizeKr != null && edited.sizeKr!.isNotEmpty) params['sizeKr'] = edited.sizeKr!;
    if (edited.category != null && edited.category!.isNotEmpty) params['category'] = edited.category!;
    if (edited.barcode != null && edited.barcode!.isNotEmpty) params['barcode'] = edited.barcode!;

    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    context.push('/register${query.isNotEmpty ? "?$query" : ""}');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 이미지 선택 영역
        if (_imageBytes == null) ...[
          const SizedBox(height: 32),
          const Icon(Icons.image_search, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Center(
              child: Text('상품 사진을 촬영하거나 선택하세요',
                  style: TextStyle(color: Colors.grey))),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('촬영'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('갤러리'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                ),
              ),
            ],
          ),
        ],

        // 이미지 프리뷰
        if (_imageBytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_imageBytes!, height: 200, fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  child: const Text('다시 선택'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _analyzing ? null : _analyze,
                  icon: _analyzing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_analyzing ? '분석 중...' : 'AI 분석'),
                ),
              ),
            ],
          ),
        ],

        // 에러
        if (_error != null) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: TextStyle(
                            color: Colors.red.shade700, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ],

        // 결과
        if (_result != null) ...[
          const SizedBox(height: 16),
          _RecognitionResultCard(
            result: _result!,
            onRegister: (edited) => _goToRegister(edited),
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════
// 인식 결과 카드
// ══════════════════════════════════════════════════

class _RecognitionResultCard extends StatefulWidget {
  final ProductRecognitionResult result;
  final ValueChanged<ProductRecognitionResult> onRegister;

  const _RecognitionResultCard({
    required this.result,
    required this.onRegister,
  });

  @override
  State<_RecognitionResultCard> createState() => _RecognitionResultCardState();
}

class _RecognitionResultCardState extends State<_RecognitionResultCard> {
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCodeCtrl;
  late final TextEditingController _modelNameCtrl;
  late final TextEditingController _sizeCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _genderCtrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _brandCtrl = TextEditingController(text: widget.result.brand ?? '');
    _modelCodeCtrl = TextEditingController(text: widget.result.modelCode ?? '');
    _modelNameCtrl = TextEditingController(text: widget.result.modelName ?? '');
    _sizeCtrl = TextEditingController(text: widget.result.sizeKr ?? '');
    _barcodeCtrl = TextEditingController(text: widget.result.barcode ?? '');
    _categoryCtrl = TextEditingController(text: widget.result.category ?? '');
    _genderCtrl = TextEditingController(text: widget.result.gender ?? '');
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCodeCtrl.dispose();
    _modelNameCtrl.dispose();
    _sizeCtrl.dispose();
    _barcodeCtrl.dispose();
    _categoryCtrl.dispose();
    _genderCtrl.dispose();
    super.dispose();
  }

  ProductRecognitionResult _buildEdited() => ProductRecognitionResult(
        brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
        modelCode: _modelCodeCtrl.text.trim().isEmpty ? null : _modelCodeCtrl.text.trim(),
        modelName: _modelNameCtrl.text.trim().isEmpty ? null : _modelNameCtrl.text.trim(),
        sizeKr: _sizeCtrl.text.trim().isEmpty ? null : _sizeCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
        category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
        gender: _genderCtrl.text.trim().isEmpty ? null : _genderCtrl.text.trim(),
        providerUsed: widget.result.providerUsed,
        rawResponse: widget.result.rawResponse,
      );

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.purple, size: 18),
                const SizedBox(width: 8),
                Text('AI 인식 결과',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold, color: Colors.purple)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(r.providerUsed,
                      style: TextStyle(
                          fontSize: 10, color: Colors.purple.shade700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_editing) ...[
              _editRow('브랜드', _brandCtrl),
              _editRow('모델코드', _modelCodeCtrl),
              _editRow('모델명', _modelNameCtrl),
              _editRow('사이즈', _sizeCtrl),
              _editRow('바코드', _barcodeCtrl),
              _editRow('카테고리', _categoryCtrl),
              _editRow('성별', _genderCtrl),
            ] else ...[
              if (r.brand != null) _row('브랜드', r.brand!),
              if (r.modelCode != null) _row('모델코드', r.modelCode!),
              if (r.modelName != null) _row('모델명', r.modelName!),
              if (r.sizeKr != null) _row('사이즈', r.sizeKr!),
              if (r.barcode != null) _row('바코드', r.barcode!),
              if (r.category != null) _row('카테고리', r.category!),
              if (r.gender != null) _row('성별', r.gender!),
              if (!r.hasUsefulData)
                const Text('인식 결과가 없습니다.',
                    style: TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 12),
            if (r.hasUsefulData || _editing) ...[
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _editing = !_editing),
                    icon: Icon(_editing ? Icons.check : Icons.edit, size: 16),
                    label: Text(_editing ? '완료' : '수정',
                        style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => widget.onRegister(_buildEdited()),
                      icon: const Icon(Icons.add_box),
                      label: const Text('이 정보로 입고 등록'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
              width: 70,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _editRow(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 70,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 유틸 / Providers
// ══════════════════════════════════════════════════

String _statusLabel(String status) => switch (status) {
      'ORDER_PLACED' => '주문완료',
      'OFFICE_STOCK' => '사무실재고',
      'LISTED' => '리스팅',
      'SOLD' => '판매완료',
      'OUTGOING' => '발송중',
      'IN_INSPECTION' => '검수중',
      'SETTLED' => '정산완료',
      'POIZON_STORAGE' => '포이즌보관',
      'DEFECT_FOR_SALE' => '하자판매',
      'DEFECT_HELD' => '하자보류',
      'DEFECT_SOLD' => '하자판매완료',
      'DEFECT_SETTLED' => '하자정산',
      'RETURNING' => '반품중',
      'CANCEL_RETURNING' => '취소반품',
      'REPAIRING' => '수선중',
      'SUPPLIER_RETURN' => '공급사반품',
      'ORDER_CANCELLED' => '주문취소',
      'DISPOSED' => '폐기',
      'SAMPLE' => '샘플',
      _ => status,
    };

typedef _StatusStyle = ({Color bg, Color border, Color text});

_StatusStyle _statusBadgeStyle(String status) {
  return switch (status) {
    'LISTED' => (
        bg: const Color(0xFFE8F5E9),
        border: const Color(0xFF81C784),
        text: const Color(0xFF2E7D32),
      ),
    'POIZON_STORAGE' => (
        bg: const Color(0xFFFFF3E0),
        border: const Color(0xFFFFB74D),
        text: const Color(0xFFE65100),
      ),
    _ => (
        bg: const Color(0xFFF5F5F5),
        border: const Color(0xFFBDBDBD),
        text: const Color(0xFF9E9E9E),
      ),
  };
}

final _productForScanProvider =
    FutureProvider.family<Product?, String>((ref, productId) {
  return ref.watch(masterDaoProvider).getProductById(productId);
});

// 동일 모델+사이즈 아이템별 구매 정보 (구매처명 포함)
typedef _ItemPurchaseInfo = ({
  ItemData item,
  String? purchaseDate,
  int? purchasePrice,
  String? sourceName,
});

final _modelSizeStockProvider = FutureProvider.family<List<_ItemPurchaseInfo>,
    ({String productId, String sizeKr})>((ref, args) async {
  final allItems =
      await ref.watch(itemDaoProvider).getAllByProductId(args.productId);
  final sizeItems = allItems
      .where((i) =>
          i.sizeKr == args.sizeKr && i.currentStatus != 'SETTLED')
      .toList();

  final purchaseMap = await ref
      .watch(purchaseDaoProvider)
      .getByItemIds(sizeItems.map((i) => i.id).toList());
  final sourcesMap = await ref.watch(masterDaoProvider).getAllSourcesMap();

  return sizeItems.map((item) {
    final purchase = purchaseMap[item.id];
    final sourceName = purchase?.sourceId != null
        ? sourcesMap[purchase!.sourceId]?.name
        : null;
    return (
      item: item,
      purchaseDate: purchase?.purchaseDate,
      purchasePrice: purchase?.purchasePrice,
      sourceName: sourceName,
    );
  }).toList();
});
