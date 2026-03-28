import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../inventory_providers.dart';
import '../status_actions.dart';

// ══════════════════════════════════════════════════
// 일괄 처리 하단 액션바
// ══════════════════════════════════════════════════

class BatchActionBar extends ConsumerWidget {
  final Set<String> selectedIds;
  final VoidCallback onDone;

  const BatchActionBar(
      {super.key, required this.selectedIds, required this.onDone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(inventoryFilterProvider);
    final currentFilterDef = findCurrentFilter(filter);
    final buttons = _buildButtons(context, ref, currentFilterDef?.statuses);

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
            Text('${selectedIds.length}개',
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

  List<Widget> _buildButtons(
      BuildContext context, WidgetRef ref, List<String>? statuses) {
    if (statuses == null) {
      return [
        _btn(context, ref, '상태변경', Icons.swap_vert_rounded, AppColors.primary,
            () => _batchStatusChange(context, ref)),
      ];
    }

    final s = statuses.toSet();
    const gap = SizedBox(width: 8);

    // 판매중: LISTED, POIZON_STORAGE
    if (s.contains('LISTED') || s.contains('POIZON_STORAGE')) {
      return [
        if (s.contains('LISTED')) ...[
          _btn(context, ref, '발송', Icons.local_shipping,
              AppColors.statusOutgoing, () => _batchSellAndShip(context, ref)),
          gap,
          _btn(
              context,
              ref,
              '리스팅취소',
              Icons.warehouse,
              Colors.blue,
              () => _batchSimpleTransition(
                  context, ref, 'LISTED', 'OFFICE_STOCK', '리스팅 취소')),
        ],
        if (s.contains('POIZON_STORAGE')) ...[
          if (s.contains('LISTED')) gap,
          _btn(
              context,
              ref,
              '정산완료',
              Icons.check_circle,
              AppColors.success,
              () => _batchSimpleTransition(
                  context, ref, 'POIZON_STORAGE', 'SETTLED', '보관판매 정산')),
          gap,
          _btn(
              context,
              ref,
              '반송전환',
              Icons.local_shipping_outlined,
              Colors.indigo,
              () => _batchSimpleTransition(
                  context, ref, 'POIZON_STORAGE', 'CANCEL_RETURNING', '반송 전환')),
        ],
      ];
    }

    // 발송·검수: OUTGOING, IN_INSPECTION
    if (s.contains('OUTGOING') || s.contains('IN_INSPECTION')) {
      return [
        if (s.contains('OUTGOING')) ...[
          _btn(
              context,
              ref,
              '검수도착',
              Icons.fact_check,
              Colors.purple,
              () => _batchSimpleTransition(
                  context, ref, 'OUTGOING', 'IN_INSPECTION', '검수 도착')),
        ],
        if (s.contains('IN_INSPECTION')) ...[
          if (s.contains('OUTGOING')) gap,
          _btn(context, ref, '검수통과', Icons.check_circle, AppColors.success,
              () => _batchInspectionPass(context, ref)),
          gap,
          _btn(context, ref, '반려', Icons.warning_amber, Colors.amber,
              () => _batchInspectionReject(context, ref)),
        ],
      ];
    }

    // 미등록: ORDER_PLACED, OFFICE_STOCK
    if (s.contains('ORDER_PLACED') || s.contains('OFFICE_STOCK')) {
      return [
        if (s.contains('ORDER_PLACED')) ...[
          _btn(
              context,
              ref,
              '입고',
              Icons.warehouse,
              Colors.blue,
              () => _batchSimpleTransition(
                  context, ref, 'ORDER_PLACED', 'OFFICE_STOCK', '입고')),
          gap,
          _btn(
              context,
              ref,
              '주문취소',
              Icons.cancel,
              Colors.red,
              () => _batchSimpleTransition(
                  context, ref, 'ORDER_PLACED', 'ORDER_CANCELLED', '주문 취소')),
        ],
        if (s.contains('OFFICE_STOCK')) ...[
          if (s.contains('ORDER_PLACED')) gap,
          _btn(context, ref, '리스팅등록', Icons.sell, Colors.teal,
              () => _batchStatusChange(context, ref)),
          gap,
          _btn(
              context,
              ref,
              '공급처반품',
              Icons.undo,
              Colors.blueGrey,
              () => _batchSimpleTransition(
                  context, ref, 'OFFICE_STOCK', 'SUPPLIER_RETURN', '공급처 반품')),
          gap,
          _btn(
              context,
              ref,
              '폐기',
              Icons.card_giftcard,
              Colors.pink,
              () => _batchSimpleTransition(
                  context, ref, 'OFFICE_STOCK', 'SAMPLE', '폐기')),
        ],
      ];
    }

    // 기타 → 범용
    return [
      _btn(context, ref, '상태변경', Icons.swap_vert_rounded, AppColors.primary,
          () => _batchStatusChange(context, ref)),
    ];
  }

  Widget _btn(BuildContext context, WidgetRef ref, String label, IconData icon,
      Color color, Future<void> Function() action) {
    return OutlinedButton.icon(
      onPressed: action,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withAlpha(80)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // ── 공통: 단순 상태 전이 ──

  Future<void> _batchSimpleTransition(BuildContext context, WidgetRef ref,
      String fromStatus, String toStatus, String actionLabel) async {
    final items = <ItemData>[];
    for (final id in selectedIds) {
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

    final isSettle = toStatus == 'SETTLED' || toStatus == 'DEFECT_SETTLED';
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

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

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${items.length}건 $actionLabel 완료')),
      );
      onDone();
    }
  }

  // ── 발송 (LISTED → OUTGOING) ──

  Future<void> _batchSellAndShip(BuildContext context, WidgetRef ref) async {
    final items = <ItemData>[];
    final sales = <String, SaleData>{};
    final products = <String, Product>{};

    for (final id in selectedIds) {
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

    if (result == true && context.mounted) onDone();
  }

  // ── 검수 통과 (IN_INSPECTION → SETTLED) ──

  Future<void> _batchInspectionPass(BuildContext context, WidgetRef ref) async {
    final items = <ItemData>[];
    for (final id in selectedIds) {
      final item = await ref.read(itemDaoProvider).getById(id);
      if (item != null && item.currentStatus == 'IN_INSPECTION')
        items.add(item);
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

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
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

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${items.length}건 검수 통과 완료')),
      );
      onDone();
    }
  }

  // ── 검수 반려 (IN_INSPECTION → 바텀시트에서 선택) ──

  Future<void> _batchInspectionReject(
      BuildContext context, WidgetRef ref) async {
    final items = <ItemData>[];
    for (final id in selectedIds) {
      final item = await ref.read(itemDaoProvider).getById(id);
      if (item != null && item.currentStatus == 'IN_INSPECTION')
        items.add(item);
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

    for (final item in items) {
      await ref.read(itemDaoProvider).updateStatus(item.id, chosen.targetStatus,
          note: '일괄 ${chosen.label}');
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${items.length}건 ${chosen.label} 완료')),
      );
      onDone();
    }
  }

  // ── 범용 상태 변경 ──

  Future<void> _batchStatusChange(BuildContext context, WidgetRef ref) async {
    final items = <ItemData>[];
    for (final id in selectedIds) {
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

    for (final item in items) {
      await ref.read(itemDaoProvider).updateStatus(item.id, chosen.targetStatus,
          note: '일괄 ${chosen.label}');
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${items.length}건 ${chosen.label} 완료')),
      );
      onDone();
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
  final _trackingCtrl = TextEditingController();
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
    _trackingCtrl.dispose();
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  const SizedBox(height: 8),
                  TextField(
                    controller: _trackingCtrl,
                    decoration: const InputDecoration(
                      labelText: '운송장 번호 (선택)',
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    const uuid = Uuid();

    for (final item in widget.items) {
      final sellPrice = int.tryParse(_priceControllers[item.id]?.text ?? '');
      if (sellPrice == null) continue;

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
                trackingNumber: Value(_trackingCtrl.text.isNotEmpty
                    ? _trackingCtrl.text.trim()
                    : null),
                platformFeeRate: Value(sale.platformFeeRate),
              ),
            );
      }

      if (_trackingCtrl.text.trim().isNotEmpty) {
        await ref.read(subRecordDaoProvider).addShipment(
              ShipmentsCompanion(
                id: Value(uuid.v4()),
                itemId: Value(item.id),
                seq: const Value(0),
                trackingNumber: Value(_trackingCtrl.text.trim()),
                outgoingDate: Value(_shipDate),
                platform: Value(sale?.platform),
                createdAt: Value(DateTime.now().toIso8601String()),
              ),
            );
      }

      await ref.read(itemDaoProvider).updateStatus(item.id, 'OUTGOING',
          note: '일괄 발송 (${NumberFormat('#,###').format(sellPrice)}원)');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.items.length}건 발송 완료')),
      );
      Navigator.pop(context, true);
    }
  }
}
