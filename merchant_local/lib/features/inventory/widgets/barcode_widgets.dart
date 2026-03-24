import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../inventory_providers.dart';

// ══════════════════════════════════════════════════
// 바코드 스캔 시트
// ══════════════════════════════════════════════════

class BarcodeScanSheet extends StatefulWidget {
  const BarcodeScanSheet({super.key});
  @override
  State<BarcodeScanSheet> createState() => _BarcodeScanSheetState();
}

class _BarcodeScanSheetState extends State<BarcodeScanSheet> {
  final _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal, facing: CameraFacing.back);
  bool _scanned = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const Text('바코드 스캔',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.flash_on, size: 20),
                onPressed: () => _ctrl.toggleTorch()),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Expanded(
          child: Stack(children: [
            MobileScanner(
              controller: _ctrl,
              onDetect: (c) {
                if (_scanned) return;
                final code = c.barcodes.firstOrNull?.rawValue;
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
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════
// 바코드 결과 시트
// ══════════════════════════════════════════════════

final _barcodeProductProvider =
    FutureProvider.family<Product?, String>((ref, productId) {
  return ref.watch(masterDaoProvider).getProductById(productId);
});

final _siblingItemsProvider =
    FutureProvider.family<List<ItemData>, String>((ref, productId) {
  return ref.watch(itemDaoProvider).getAllByProductId(productId);
});

class BarcodeResultSheet extends ConsumerWidget {
  final String barcode;
  final ItemData item;
  final ScrollController scrollController;

  const BarcodeResultSheet({
    super.key,
    required this.barcode,
    required this.item,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(_barcodeProductProvider(item.productId));
    final siblingsAsync = ref.watch(_siblingItemsProvider(item.productId));

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          productAsync.when(
            data: (product) {
              if (product == null) return const SizedBox.shrink();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    productImage(product.imageUrl),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.modelName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(product.modelCode,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13)),
                          Text('바코드: $barcode',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ]),
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          Text('사이즈별 현황',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          siblingsAsync.when(
            data: (siblings) {
              if (siblings.isEmpty) return const Text('아이템이 없습니다');
              final grouped = <String, List<ItemData>>{};
              for (final s in siblings) {
                grouped.putIfAbsent(s.sizeKr, () => []).add(s);
              }
              return Column(
                children: grouped.entries.map((e) {
                  final activeCount = e.value
                      .where((i) => !{'SETTLED', 'DEFECT_SETTLED',
                              'ORDER_CANCELLED', 'SUPPLIER_RETURN', 'DISPOSED'}
                          .contains(i.currentStatus))
                      .length;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: activeCount > 0
                            ? AppColors.successBg
                            : AppColors.surfaceVariant,
                        child: Text('$activeCount',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: activeCount > 0
                                    ? AppColors.success
                                    : AppColors.textTertiary)),
                      ),
                      title: Text('사이즈 ${e.key}',
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text('총 ${e.value.length}건',
                          style: const TextStyle(fontSize: 12)),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/item/${e.value.first.id}');
                      },
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('오류: $e'),
          ),
          const SizedBox(height: 12),
          Row(children: [
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
          ]),
        ],
      ),
    );
  }
}
