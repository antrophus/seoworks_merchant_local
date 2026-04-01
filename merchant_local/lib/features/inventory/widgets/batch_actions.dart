import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../status_actions.dart';

// ══════════════════════════════════════════════════
// 일괄 처리 하단 액션바
// ══════════════════════════════════════════════════

class BatchActionBar extends ConsumerStatefulWidget {
  final Set<String> selectedIds;
  final String? effectiveFilter;
  final VoidCallback onDone;

  const BatchActionBar({
    super.key,
    required this.selectedIds,
    this.effectiveFilter,
    required this.onDone,
  });

  @override
  ConsumerState<BatchActionBar> createState() => _BatchActionBarState();
}

class _BatchActionBarState extends ConsumerState<BatchActionBar> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final buttons = _buildButtons(context, widget.effectiveFilter);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: const Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Text('${widget.selectedIds.length}개',
                style:
                    AppTheme.dataStyle(fontSize: 16, color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: buttons),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildButtons(BuildContext context, String? effectiveFilter) {
    const gap = SizedBox(width: 8);

    switch (effectiveFilter) {
      case 'LISTED':
        return [
          _btn(context, '발송', Icons.local_shipping, AppColors.statusOutgoing,
              () => _batchSellAndShip(context)),
          gap,
          _btn(context, '리스팅취소', Icons.warehouse, Colors.blue,
              () => _batchSimpleTransition(context, 'LISTED', 'OFFICE_STOCK', '리스팅 취소')),
        ];

      case 'POIZON_STORAGE':
        return [
          _btn(context, '정산완료', Icons.check_circle, AppColors.success,
              () => _batchSimpleTransition(context, 'POIZON_STORAGE', 'SETTLED', '보관판매 정산')),
          gap,
          _btn(context, '반송전환', Icons.local_shipping_outlined, Colors.indigo,
              () => _batchSimpleTransition(context, 'POIZON_STORAGE', 'CANCEL_RETURNING', '반송 전환')),
        ];

      case 'OUTGOING':
        return [
          _btn(context, '검수도착', Icons.fact_check, Colors.purple,
              () => _batchSimpleTransition(context, 'OUTGOING', 'IN_INSPECTION', '검수 도착')),
        ];

      case 'IN_INSPECTION':
        return [
          _btn(context, '검수통과', Icons.check_circle, AppColors.success,
              () => _batchInspectionPass(context)),
          gap,
          _btn(context, '반려', Icons.warning_amber, Colors.amber,
              () => _batchInspectionReject(context)),
        ];

      case 'ORDER_PLACED':
        return [
          _btn(context, '입고', Icons.warehouse, Colors.blue,
              () => _batchSimpleTransition(context, 'ORDER_PLACED', 'OFFICE_STOCK', '입고')),
          gap,
          _btn(context, '주문취소', Icons.cancel, Colors.red,
              () => _batchSimpleTransition(context, 'ORDER_PLACED', 'ORDER_CANCELLED', '주문 취소')),
        ];

      case 'OFFICE_STOCK':
        return [
          _btn(context, '리스팅등록', Icons.sell, Colors.teal,
              () => _batchListing(context)),
          gap,
          _btn(context, '공급처반품', Icons.undo, Colors.blueGrey,
              () => _batchSimpleTransition(context, 'OFFICE_STOCK', 'SUPPLIER_RETURN', '공급처 반품')),
          gap,
          _btn(context, '폐기', Icons.delete_outline, Colors.pink,
              () => _batchSimpleTransition(context, 'OFFICE_STOCK', 'DISPOSED', '폐기')),
        ];

      default:
        // CSV(서브탭 미선택) 또는 null → 서브탭을 먼저 선택하도록 안내
        if (effectiveFilter != null && effectiveFilter.contains(',')) {
          final statuses = effectiveFilter.split(',').toSet();
          final hints = <String>[];
          if (statuses.containsAll({'LISTED', 'POIZON_STORAGE'})) {
            hints.add('리스팅 / 포이즌보관 탭을 선택하세요');
          } else if (statuses.containsAll({'OUTGOING', 'IN_INSPECTION'})) {
            hints.add('발송중 / 검수중 탭을 선택하세요');
          } else if (statuses.containsAll({'ORDER_PLACED', 'OFFICE_STOCK'})) {
            hints.add('입고대기 / 미등록재고 탭을 선택하세요');
          }
          if (hints.isNotEmpty) {
            return [
              Text(hints.first,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ];
          }
        }
        return [
          _btn(context, '상태변경', Icons.swap_vert_rounded, AppColors.primary,
              () => _batchStatusChange(context)),
        ];
    }
  }

  Widget _btn(BuildContext context, String label, IconData icon,
      Color color, Future<void> Function() action) {
    return OutlinedButton.icon(
      onPressed: _busy
          ? null
          : () async {
              if (_busy) return;
              setState(() => _busy = true);
              try {
                await action();
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      icon: Icon(icon, size: 16, color: _busy ? Colors.grey : color),
      label: Text(label,
          style: TextStyle(fontSize: 12, color: _busy ? Colors.grey : color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: (_busy ? Colors.grey : color).withAlpha(80)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // ── 공통: 단순 상태 전이 ──

  Future<void> _batchSimpleTransition(BuildContext context,
      String fromStatus, String toStatus, String actionLabel) async {
    final items = <ItemData>[];
    for (final id in widget.selectedIds) {
      final item = await ref.read(itemDaoProvider).getById(id);
      if (item != null && item.currentStatus == fromStatus) items.add(item);
    }

    if (items.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$actionLabel 처리할 수 있는 아이템이 없습니다')),
        );
      }
      return;
    }
    if (!context.mounted) return;

    final confirmed = await _confirmDialog(
        context, '${items.length}개', '$actionLabel 처리하시겠습니까?');
    if (confirmed != true) return;
    if (!context.mounted) return;

    final isSettle = toStatus == 'SETTLED' || toStatus == 'DEFECT_SETTLED';
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await ref.read(databaseProvider).transaction(() async {
      for (final item in items) {
        // 정산 전이 시 Sale의 settledAt 자동 설정
        if (isSettle) {
          final sale = await ref.read(saleDaoProvider).getByItemId(item.id);
          if (sale != null) {
            await ref.read(saleDaoProvider).updateSale(
                  sale.id,
                  SalesCompanion(
                    itemId: Value(item.id),
                    platform: Value(sale.platform),
                    sellPrice: Value(sale.sellPrice),
                    listedPrice: Value(sale.listedPrice),
                    saleDate: Value(sale.saleDate ?? today),
                    settledAt: Value(today),
                    platformFeeRate: Value(sale.platformFeeRate),
                  ),
                );
          }
        }
        await ref
            .read(itemDaoProvider)
            .updateStatus(item.id, toStatus, note: '일괄 $actionLabel');
      }
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${items.length}건 $actionLabel 완료')),
      );
      widget.onDone();
    }
  }

  // ── 리스팅 등록 (OFFICE_STOCK → LISTED) ──

  Future<void> _batchListing(BuildContext context) async {
    final items = <ItemData>[];
    for (final id in widget.selectedIds) {
      final item = await ref.read(itemDaoProvider).getById(id);
      if (item != null && item.currentStatus == 'OFFICE_STOCK') items.add(item);
    }

    if (items.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사무실재고 상태의 아이템만 리스팅 등록할 수 있습니다')),
        );
      }
      return;
    }

    final products = <String, Product>{};
    for (final item in items) {
      final prod =
          await ref.read(masterDaoProvider).getProductById(item.productId);
      if (prod != null) products[item.productId] = prod;
    }

    if (!context.mounted) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BatchListingSheet(items: items, products: products),
    );

    if (result == true && context.mounted) widget.onDone();
  }

  // ── 발송 (LISTED → OUTGOING) ──

  Future<void> _batchSellAndShip(BuildContext context) async {
    final items = <ItemData>[];
    final sales = <String, SaleData>{};
    final products = <String, Product>{};

    for (final id in widget.selectedIds) {
      final item = await ref.read(itemDaoProvider).getById(id);
      if (item == null) continue;
      items.add(item);
      final sale = await ref.read(saleDaoProvider).getByItemId(id);
      if (sale != null) sales[id] = sale;
      final prod =
          await ref.read(masterDaoProvider).getProductById(item.productId);
      if (prod != null) products[item.productId] = prod;
    }

    final listedItems =
        items.where((i) => i.currentStatus == 'LISTED').toList();
    if (listedItems.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('판매중(리스팅) 상태의 아이템만 발송 처리할 수 있습니다')),
        );
      }
      return;
    }
    if (!context.mounted) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BatchSellShipSheet(
        items: listedItems,
        sales: sales,
        products: products,
      ),
    );

    if (result == true && context.mounted) widget.onDone();
  }

  // ── 검수 통과 (IN_INSPECTION → SETTLED) ──

  Future<void> _batchInspectionPass(BuildContext context) async {
    final items = <ItemData>[];
    for (final id in widget.selectedIds) {
      final item = await ref.read(itemDaoProvider).getById(id);
      if (item != null && item.currentStatus == 'IN_INSPECTION') {
        items.add(item);
      }
    }

    if (items.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('검수중 상태의 아이템만 검수 통과 처리할 수 있습니다')),
        );
      }
      return;
    }
    if (!context.mounted) return;

    final confirmed = await _confirmDialog(
        context, '${items.length}개', '검수 통과(정산) 처리하시겠습니까?');
    if (confirmed != true) return;
    if (!context.mounted) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await ref.read(databaseProvider).transaction(() async {
      for (final item in items) {
        final sale = await ref.read(saleDaoProvider).getByItemId(item.id);
        if (sale != null) {
          await ref.read(saleDaoProvider).updateSale(
                sale.id,
                SalesCompanion(
                  itemId: Value(item.id),
                  platform: Value(sale.platform),
                  sellPrice: Value(sale.sellPrice),
                  listedPrice: Value(sale.listedPrice),
                  saleDate: Value(sale.saleDate ?? today),
                  settledAt: Value(today),
                  platformFeeRate: Value(sale.platformFeeRate),
                ),
              );
        }
        await ref
            .read(itemDaoProvider)
            .updateStatus(item.id, 'SETTLED', note: '일괄 검수 통과');
      }
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${items.length}건 검수 통과 완료')),
      );
      widget.onDone();
    }
  }

  // ── 검수 반려 (IN_INSPECTION → 바텀시트에서 선택) ──

  Future<void> _batchInspectionReject(BuildContext context) async {
    final items = <ItemData>[];
    for (final id in widget.selectedIds) {
      final item = await ref.read(itemDaoProvider).getById(id);
      if (item != null && item.currentStatus == 'IN_INSPECTION') {
        items.add(item);
      }
    }

    if (items.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('검수중 상태의 아이템만 반려 처리할 수 있습니다')),
        );
      }
      return;
    }
    if (!context.mounted) return;

    // 검수통과 제외한 나머지 액션 표시
    final allActions = statusActions['IN_INSPECTION'] ?? [];
    final rejectActions =
        allActions.where((a) => a.targetStatus != 'SETTLED').toList();

    final chosen = await showModalBottomSheet<StatusAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('반려 처리 (${items.length}개)',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            ...rejectActions.map((a) => ListTile(
                  leading: Icon(a.icon, color: a.color),
                  title: Text(a.label),
                  onTap: () => Navigator.pop(ctx, a),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (chosen == null || !context.mounted) return;

    final confirmed = await _confirmDialog(
        context, '${items.length}개', '${chosen.label} 처리하시겠습니까?');
    if (confirmed != true) return;
    if (!context.mounted) return;

    for (final item in items) {
      await ref.read(itemDaoProvider).updateStatus(item.id, chosen.targetStatus,
          note: '일괄 ${chosen.label}');
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${items.length}건 ${chosen.label} 완료')),
      );
      widget.onDone();
    }
  }

  // ── 범용 상태 변경 ──

  Future<void> _batchStatusChange(BuildContext context) async {
    final items = <ItemData>[];
    for (final id in widget.selectedIds) {
      final item = await ref.read(itemDaoProvider).getById(id);
      if (item != null) items.add(item);
    }

    final statuses = items.map((i) => i.currentStatus).toSet();
    if (statuses.length != 1) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('같은 상태의 아이템만 일괄 변경할 수 있습니다')),
        );
      }
      return;
    }

    final currentStatus = statuses.first;
    final actions = statusActions[currentStatus];
    if (actions == null || actions.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이 상태에서 가능한 액션이 없습니다')),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final chosen = await showModalBottomSheet<StatusAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('일괄 상태 변경 (${items.length}개)',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            ...actions.map((a) => ListTile(
                  leading: Icon(a.icon, color: a.color),
                  title: Text(a.label),
                  onTap: () => Navigator.pop(ctx, a),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (chosen == null || !context.mounted) return;

    final confirmed = await _confirmDialog(
        context, '${items.length}개', '${chosen.label} 처리하시겠습니까?');
    if (confirmed != true) return;
    if (!context.mounted) return;

    await ref.read(databaseProvider).transaction(() async {
      for (final item in items) {
        await ref.read(itemDaoProvider).updateStatus(
            item.id, chosen.targetStatus,
            note: '일괄 ${chosen.label}');
      }
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${items.length}건 ${chosen.label} 완료')),
      );
      widget.onDone();
    }
  }

  // ── 확인 다이얼로그 ──

  Future<bool?> _confirmDialog(
      BuildContext context, String count, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일괄 처리 확인'),
        content: Text.rich(TextSpan(children: [
          TextSpan(
              text: count,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
          TextSpan(text: ' 아이템을 $message'),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('확인')),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 플랫폼 목록 (리스팅/발송 공통)
// ══════════════════════════════════════════════════

const _listingPlatforms = ['POIZON', 'KREAM', 'SOLDOUT', 'DIRECT', 'OTHER'];
const _listingPlatformLabels = {
  'POIZON': 'POIZON (득물)',
  'KREAM': 'KREAM',
  'SOLDOUT': 'SOLDOUT',
  'DIRECT': '직거래',
  'OTHER': '기타',
};

// ══════════════════════════════════════════════════
// 일괄 리스팅 등록 바텀시트
// ══════════════════════════════════════════════════

class _BatchListingSheet extends ConsumerStatefulWidget {
  final List<ItemData> items;
  final Map<String, Product> products;

  const _BatchListingSheet({required this.items, required this.products});

  @override
  ConsumerState<_BatchListingSheet> createState() => _BatchListingSheetState();
}

class _BatchListingSheetState extends ConsumerState<_BatchListingSheet> {
  String _platform = 'POIZON';
  late final Map<String, TextEditingController> _priceControllers;
  final _bulkPriceCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _priceControllers = {
      for (final item in widget.items) item.id: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    _bulkPriceCtrl.dispose();
    super.dispose();
  }

  void _applyBulkPrice() {
    final price = _bulkPriceCtrl.text.trim();
    if (price.isEmpty) return;
    setState(() {
      for (final c in _priceControllers.values) {
        c.text = price;
      }
    });
  }

  Future<void> _submit() async {
    // 등록가 미입력 아이템 체크
    final missing = widget.items
        .where((i) =>
            int.tryParse(_priceControllers[i.id]?.text.trim() ?? '') == null)
        .toList();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('등록가를 모두 입력하세요 (${missing.length}개 미입력)')),
      );
      return;
    }

    setState(() => _saving = true);

    final dao = ref.read(saleDaoProvider);
    final now = DateTime.now().toIso8601String();
    int successCount = 0;
    int failureCount = 0;

    for (final item in widget.items) {
      try {
        final listedPrice = int.parse(_priceControllers[item.id]!.text.trim());

        final existing = await dao.getByItemId(item.id);
        if (existing != null) {
          await dao.updateSale(
            existing.id,
            SalesCompanion(
              itemId: Value(item.id),
              platform: Value(_platform),
              listedPrice: Value(listedPrice),
              dataSource: const Value('manual'),
            ),
          );
        } else {
          await dao.insertSale(SalesCompanion(
            id: Value(const Uuid().v4()),
            itemId: Value(item.id),
            platform: Value(_platform),
            listedPrice: Value(listedPrice),
            dataSource: const Value('manual'),
            createdAt: Value(now),
          ));
        }

        await ref
            .read(itemDaoProvider)
            .updateStatus(item.id, 'LISTED', note: '일괄 리스팅 등록 ($_platform)');
        successCount++;
      } catch (_) {
        failureCount++;
      }
    }

    if (mounted) {
      final msg = failureCount == 0
          ? '${widget.items.length}건 리스팅 등록 완료'
          : successCount > 0
              ? '$successCount건 완료, $failureCount건 실패'
              : '$failureCount건 처리 실패';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (successCount > 0) {
        Navigator.pop(context, true);
      } else {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, sc) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '일괄 리스팅 등록 (${widget.items.length}개)',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                controller: sc,
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                children: [
                  // 플랫폼 선택
                  DropdownButtonFormField<String>(
                    initialValue: _platform,
                    decoration: const InputDecoration(
                      labelText: '판매 플랫폼',
                      prefixIcon: Icon(Icons.storefront),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _listingPlatforms
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(_listingPlatformLabels[p] ?? p),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _platform = v!),
                  ),
                  const SizedBox(height: 12),

                  // 일괄 등록가 입력
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _bulkPriceCtrl,
                          decoration: const InputDecoration(
                            labelText: '등록가 일괄 적용 (원)',
                            isDense: true,
                            prefixIcon: Icon(Icons.label_outline),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onTap: () => _bulkPriceCtrl.clear(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _applyBulkPrice,
                        child: const Text('전체 적용'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),

                  // 아이템별 등록가 입력
                  for (final item in widget.items) ...[
                    _itemRow(item, fmt),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // 하단 버튼
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 8),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.sell),
                        label: Text('${widget.items.length}개 리스팅 등록'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('취소'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(ItemData item, NumberFormat fmt) {
    final product = widget.products[item.productId];
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product?.modelCode ?? '?',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'KR ${item.sizeKr}${item.sizeEu != null ? ' / EU ${item.sizeEu}' : ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            controller: _priceControllers[item.id],
            decoration: const InputDecoration(
              isDense: true,
              suffixText: '원',
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 14),
            onTap: () => _priceControllers[item.id]!.clear(),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════
// 일괄 판매/발송 바텀시트
// ══════════════════════════════════════════════════

class _BatchSellShipSheet extends ConsumerStatefulWidget {
  final List<ItemData> items;
  final Map<String, SaleData> sales;
  final Map<String, Product> products;

  const _BatchSellShipSheet({
    required this.items,
    required this.sales,
    required this.products,
  });

  @override
  ConsumerState<_BatchSellShipSheet> createState() =>
      _BatchSellShipSheetState();
}

class _BatchSellShipSheetState extends ConsumerState<_BatchSellShipSheet> {
  late final Map<String, TextEditingController> _priceControllers;
  final _bulkPriceCtrl = TextEditingController();
  late String _shipDate;

  @override
  void initState() {
    super.initState();
    _shipDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _priceControllers = {};
    for (final item in widget.items) {
      final sale = widget.sales[item.id];
      _priceControllers[item.id] = TextEditingController(
        text: sale?.listedPrice?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    _bulkPriceCtrl.dispose();
    super.dispose();
  }

  void _applyBulkPrice() {
    final price = _bulkPriceCtrl.text.trim();
    if (price.isEmpty) return;
    for (final c in _priceControllers.values) {
      c.text = price;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, sc) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('일괄 판매/발송 처리',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                controller: sc,
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _bulkPriceCtrl,
                          decoration: const InputDecoration(
                            labelText: '동일 가격 일괄 적용',
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onTap: () => _bulkPriceCtrl.clear(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _applyBulkPrice,
                        child: const Text('전체 적용'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final item in widget.items) ...[
                    _batchItemRow(item),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          _shipDate = DateFormat('yyyy-MM-dd').format(picked);
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '발송일',
                        prefixIcon: Icon(Icons.calendar_today),
                        isDense: true,
                      ),
                      child: Text(_shipDate),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 8),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submit,
                        child: Text('${widget.items.length}개 발송'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('취소'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _batchItemRow(ItemData item) {
    final product = widget.products[item.productId];
    final sale = widget.sales[item.id];
    final label =
        '${product?.modelCode ?? "?"} ${item.sizeKr} ¥${NumberFormat('#,###').format(sale?.listedPrice ?? 0)}';

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(label,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            controller: _priceControllers[item.id],
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 14),
            onTap: () => _priceControllers[item.id]!.clear(),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    // 가격 미입력 체크
    final hasPrices = widget.items.any(
      (i) => int.tryParse(_priceControllers[i.id]?.text ?? '') != null,
    );
    if (!hasPrices) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('판매가를 입력하세요')),
      );
      return;
    }

    // 운송장 번호 입력 다이얼로그
    if (!context.mounted) return;
    final trackingRaw = await _askTrackingNumber(context);
    if (!context.mounted) return;
    final trackingNumber =
        (trackingRaw != null && trackingRaw.isNotEmpty) ? trackingRaw : null;

    const uuid = Uuid();
    int successCount = 0;
    int failureCount = 0;

    for (final item in widget.items) {
      final sellPrice = int.tryParse(_priceControllers[item.id]?.text ?? '');
      if (sellPrice == null) continue;

      try {
        final sale = widget.sales[item.id];

        if (sale != null) {
          await ref.read(saleDaoProvider).updateSale(
                sale.id,
                SalesCompanion(
                  itemId: Value(item.id),
                  platform: Value(sale.platform),
                  sellPrice: Value(sellPrice),
                  listedPrice: Value(sale.listedPrice),
                  saleDate: Value(_shipDate),
                  outgoingDate: Value(_shipDate),
                  trackingNumber: Value(trackingNumber),
                  platformFeeRate: Value(sale.platformFeeRate),
                ),
              );
        }

        if (trackingNumber != null) {
          await ref.read(subRecordDaoProvider).addShipment(
                ShipmentsCompanion(
                  id: Value(uuid.v4()),
                  itemId: Value(item.id),
                  seq: const Value(0),
                  trackingNumber: Value(trackingNumber),
                  outgoingDate: Value(_shipDate),
                  platform: Value(sale?.platform),
                  createdAt: Value(DateTime.now().toIso8601String()),
                ),
              );
        }

        await ref.read(itemDaoProvider).updateStatus(item.id, 'OUTGOING',
            note: '일괄 발송 (${NumberFormat('#,###').format(sellPrice)}원)');
        successCount++;
      } catch (_) {
        failureCount++;
      }
    }

    if (mounted) {
      final msg = failureCount == 0
          ? '${widget.items.length}건 발송 완료'
          : successCount > 0
              ? '$successCount건 완료, $failureCount건 실패'
              : '$failureCount건 처리 실패';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.pop(context, successCount > 0);
    }
  }

  Future<String?> _askTrackingNumber(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.local_shipping_outlined, size: 20),
            SizedBox(width: 8),
            Text('운송장 번호'),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: '운송장 번호 입력',
            prefixIcon: Icon(Icons.numbers),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('건너뛰기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
