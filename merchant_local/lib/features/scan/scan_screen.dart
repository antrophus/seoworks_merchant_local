import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/services/llm_router.dart';

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
  ItemData? _foundItem;
  bool _searching = false;
  bool _notFound = false;

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
    if (barcode == _lastBarcode || _searching) return;
    _lastBarcode = barcode;
    setState(() {
      _searching = true;
      _notFound = false;
      _foundItem = null;
    });

    final item = await ref.read(itemDaoProvider).getByBarcode(barcode);
    if (mounted) {
      setState(() {
        _searching = false;
        _foundItem = item;
        _notFound = item == null;
      });
    }
  }

  void _resetScan() {
    setState(() {
      _lastBarcode = null;
      _foundItem = null;
      _notFound = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMobile) {
      // Windows/데스크톱: 카메라 없음 → 수동 바코드 입력
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
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
          Expanded(child: _buildResult()),
        ],
      );
    }

    return Column(
      children: [
        // 카메라 뷰
        Expanded(
          flex: 3,
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
              // 스캔 프레임 오버레이
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
              // 카메라 컨트롤
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

        // 결과 영역
        Expanded(
          flex: 2,
          child: _buildResult(),
        ),
      ],
    );
  }

  Widget _buildResult() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_lastBarcode == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('바코드를 스캔하세요', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // 바코드 찾음
    if (_foundItem != null) {
      return _BarcodeFoundCard(
        barcode: _lastBarcode!,
        item: _foundItem!,
        onReset: _resetScan,
      );
    }

    // 바코드 미등록
    if (_notFound) {
      return _BarcodeNotFoundCard(
        barcode: _lastBarcode!,
        onReset: _resetScan,
        onRegister: () {
          context.push('/register');
        },
      );
    }

    return const SizedBox.shrink();
  }
}

class _BarcodeFoundCard extends ConsumerWidget {
  final String barcode;
  final ItemData item;
  final VoidCallback onReset;

  const _BarcodeFoundCard({
    required this.barcode,
    required this.item,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync =
        ref.watch(_productForScanProvider(item.productId));
    final purchaseAsync =
        ref.watch(_purchaseForScanProvider(item.id));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('바코드: $barcode',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(),
              Text('SKU: ${item.sku}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text(
                  '사이즈: ${item.sizeKr}${item.sizeEu != null ? " / EU ${item.sizeEu}" : ""}'),
              Text('상태: ${_statusLabel(item.currentStatus)}'),
              productAsync.when(
                data: (p) => p != null
                    ? Text('모델: ${p.modelName} (${p.modelCode})')
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              purchaseAsync.when(
                data: (p) => p?.purchasePrice != null
                    ? Text(
                        '매입가: ${NumberFormat('#,###').format(p!.purchasePrice)}원')
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReset,
                      child: const Text('다시 스캔'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          context.push('/item/${item.id}'),
                      child: const Text('상세 보기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarcodeNotFoundCard extends StatelessWidget {
  final String barcode;
  final VoidCallback onReset;
  final VoidCallback onRegister;

  const _BarcodeNotFoundCard({
    required this.barcode,
    required this.onReset,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text('바코드 미등록: $barcode',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('등록된 아이템이 없습니다.'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReset,
                      child: const Text('다시 스캔'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: onRegister,
                      child: const Text('입고 등록'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

  void _goToRegister() {
    if (_result == null) return;
    // 쿼리 파라미터로 인식 결과 전달
    final params = <String, String>{};
    if (_result!.brand != null) params['brand'] = _result!.brand!;
    if (_result!.modelCode != null) params['modelCode'] = _result!.modelCode!;
    if (_result!.modelName != null) params['modelName'] = _result!.modelName!;
    if (_result!.sizeKr != null) params['sizeKr'] = _result!.sizeKr!;
    if (_result!.category != null) params['category'] = _result!.category!;

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
            onRegister: _goToRegister,
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════
// 인식 결과 카드
// ══════════════════════════════════════════════════

class _RecognitionResultCard extends StatelessWidget {
  final ProductRecognitionResult result;
  final VoidCallback onRegister;

  const _RecognitionResultCard({
    required this.result,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
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
                  child: Text(result.providerUsed,
                      style: TextStyle(
                          fontSize: 10, color: Colors.purple.shade700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (result.brand != null) _row('브랜드', result.brand!),
            if (result.modelCode != null) _row('모델코드', result.modelCode!),
            if (result.modelName != null) _row('모델명', result.modelName!),
            if (result.sizeKr != null) _row('사이즈', result.sizeKr!),
            if (result.barcode != null) _row('바코드', result.barcode!),
            if (result.category != null) _row('카테고리', result.category!),
            if (result.gender != null) _row('성별', result.gender!),
            if (!result.hasUsefulData)
              const Text('인식 결과가 없습니다.',
                  style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            if (result.hasUsefulData)
              FilledButton.icon(
                onPressed: onRegister,
                icon: const Icon(Icons.add_box),
                label: const Text('이 정보로 입고 등록'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44)),
              ),
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
      _ => status,
    };

final _productForScanProvider =
    FutureProvider.family<Product?, String>((ref, productId) {
  return ref.watch(masterDaoProvider).getProductById(productId);
});

final _purchaseForScanProvider =
    FutureProvider.family<PurchaseData?, String>((ref, itemId) {
  return ref.watch(purchaseDaoProvider).getByItemId(itemId);
});
