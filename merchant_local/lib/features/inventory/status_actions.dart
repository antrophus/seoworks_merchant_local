import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

const _uuid = Uuid();

// ══════════════════════════════════════════════════
// 상태 전이 규칙
// ══════════════════════════════════════════════════

/// 현재 상태 → 가능한 액션 목록
const statusActions = <String, List<StatusAction>>{
  'ORDER_PLACED': [
    StatusAction('입고 (사무실 도착)', 'OFFICE_STOCK', Icons.warehouse, Colors.blue),
    StatusAction('주문 취소', 'ORDER_CANCELLED', Icons.cancel, Colors.red,
        needsCancel: true),
  ],
  'OFFICE_STOCK': [
    StatusAction('리스팅 등록', 'LISTED', Icons.sell, Colors.teal,
        needsListing: true),
    StatusAction(
        '공급처 반품', 'SUPPLIER_RETURN', Icons.undo, Colors.blueGrey,
        needsReturn: true),
    StatusAction('샘플/폐기', 'SAMPLE', Icons.card_giftcard, Colors.pink),
  ],
  'OUTGOING': [
    StatusAction('검수 도착', 'IN_INSPECTION', Icons.fact_check, Colors.purple),
  ],
  'IN_INSPECTION': [
    StatusAction(
        '검수 통과 (정산)', 'SETTLED', Icons.check_circle, Colors.green),
    StatusAction(
        '검수 반려 (불량판매)', 'DEFECT_FOR_SALE', Icons.warning, Colors.amber,
        needsInspection: true, defectType: 'DEFECT_SALE'),
    StatusAction(
        '검수 반려 (불량보류)', 'DEFECT_HELD', Icons.pause_circle, Colors.deepOrange,
        needsInspection: true, defectType: 'DEFECT_HELD'),
    StatusAction(
        '검수 반려 (반송)', 'RETURNING', Icons.keyboard_return, Colors.red,
        needsInspection: true, defectType: 'DEFECT_RETURN'),
    StatusAction(
        '플랫폼취소 (보관판매)', 'POIZON_STORAGE', Icons.warehouse_outlined, Colors.teal,
        needsInspection: true, defectType: 'PLATFORM_CANCEL'),
    StatusAction(
        '플랫폼취소 (반송)', 'CANCEL_RETURNING', Icons.local_shipping_outlined, Colors.indigo,
        needsInspection: true, defectType: 'PLATFORM_CANCEL'),
  ],
  'LISTED': [
    StatusAction('판매/발송 처리', 'OUTGOING', Icons.local_shipping, Colors.indigo,
        needsSellAndShip: true),
    StatusAction('리스팅 취소 (사무실 복귀)', 'OFFICE_STOCK', Icons.warehouse, Colors.blue),
    StatusAction('플랫폼취소 (보관판매)', 'POIZON_STORAGE', Icons.warehouse_outlined, Colors.teal),
  ],
  'SOLD': [
    StatusAction('발송', 'OUTGOING', Icons.local_shipping, Colors.indigo,
        needsShipment: true),
    StatusAction('판매 취소 (리스팅 복귀)', 'LISTED', Icons.undo, Colors.teal),
  ],
  'DEFECT_FOR_SALE': [
    StatusAction('불량 판매 완료', 'DEFECT_SOLD', Icons.check_circle, Colors.green),
    StatusAction('수선 시작', 'REPAIRING', Icons.build, Colors.brown,
        needsRepair: true),
  ],
  'DEFECT_SOLD': [
    StatusAction('불량 정산 완료', 'DEFECT_SETTLED', Icons.payments, Colors.grey),
  ],
  'DEFECT_HELD': [
    StatusAction('재판매 (사무실 복귀)', 'OFFICE_STOCK', Icons.warehouse, Colors.blue),
    StatusAction('수선 시작', 'REPAIRING', Icons.build, Colors.brown,
        needsRepair: true),
    StatusAction(
        '공급처 반품', 'SUPPLIER_RETURN', Icons.undo, Colors.blueGrey,
        needsReturn: true),
    StatusAction('폐기', 'DISPOSED', Icons.delete_forever, Colors.red),
  ],
  'POIZON_STORAGE': [
    StatusAction('보관판매 정산 완료', 'SETTLED', Icons.check_circle, Colors.green),
    StatusAction('반송 전환 (90일 초과/포기)', 'CANCEL_RETURNING', Icons.local_shipping_outlined, Colors.indigo),
  ],
  'CANCEL_RETURNING': [
    StatusAction('수취 완료 (재입고)', 'OFFICE_STOCK', Icons.warehouse, Colors.blue),
  ],
  'RETURNING': [
    StatusAction('사무실 도착 (재입고)', 'OFFICE_STOCK', Icons.warehouse, Colors.blue),
    StatusAction('수선 시작', 'REPAIRING', Icons.build, Colors.brown,
        needsRepair: true),
  ],
  'REPAIRING': [
    StatusAction(
        '수선 완료 → 재등록', 'OFFICE_STOCK', Icons.warehouse, Colors.blue,
        needsRepairComplete: true, repairOutcome: 'RELISTED'),
    StatusAction('수선 완료 → 공급처 반품', 'SUPPLIER_RETURN', Icons.undo,
        Colors.blueGrey,
        needsRepairComplete: true,
        repairOutcome: 'SUPPLIER_RETURN',
        needsReturn: true),
    StatusAction(
        '수선 완료 → 폐기', 'DISPOSED', Icons.delete_forever, Colors.red,
        needsRepairComplete: true, repairOutcome: 'DISPOSED'),
    StatusAction(
        '수선 완료 → 개인 전환', 'SAMPLE', Icons.person, Colors.pink,
        needsRepairComplete: true, repairOutcome: 'PERSONAL'),
  ],
};

class StatusAction {
  final String label;
  final String targetStatus;
  final IconData icon;
  final Color color;
  final bool needsShipment;
  final bool needsInspection;
  final String? defectType;
  final bool needsRepair;
  final bool needsRepairComplete;
  final String? repairOutcome;
  final bool needsCancel;
  final bool needsReturn;
  final bool needsListing;
  final bool needsSellPrice;
  final bool needsSellAndShip;

  const StatusAction(
    this.label,
    this.targetStatus,
    this.icon,
    this.color, {
    this.needsShipment = false,
    this.needsInspection = false,
    this.defectType,
    this.needsRepair = false,
    this.needsRepairComplete = false,
    this.repairOutcome,
    this.needsCancel = false,
    this.needsReturn = false,
    this.needsListing = false,
    this.needsSellPrice = false,
    this.needsSellAndShip = false,
  });
}

// ══════════════════════════════════════════════════
// 액션 시트 표시
// ══════════════════════════════════════════════════

/// 아이템의 현재 상태에 따라 가능한 액션을 Bottom Sheet로 표시
Future<bool?> showStatusActionSheet({
  required BuildContext context,
  required WidgetRef ref,
  required ItemData item,
}) async {
  final actions = statusActions[item.currentStatus];
  if (actions == null || actions.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이 상태에서 가능한 액션이 없습니다')),
    );
    return null;
  }

  // Completer: Navigator.pop으로 시트가 닫힌 후에도
  // _executeAction 결과를 올바르게 반환하기 위해 사용
  final completer = Completer<bool?>();

  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '상태 변경',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ...actions.map((action) => ListTile(
                  leading: Icon(action.icon, color: action.color),
                  title: Text(action.label),
                  trailing: Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.grey.shade400),
                  onTap: () async {
                    Navigator.pop(ctx); // 먼저 시트 닫기
                    final result = await _executeAction(
                      context: context,
                      ref: ref,
                      item: item,
                      action: action,
                    );
                    if (!completer.isCompleted) completer.complete(result);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  ).then((_) {
    // 액션 없이 시트가 닫힌 경우 (스와이프 다운 등)
    if (!completer.isCompleted) completer.complete(null);
  });

  return completer.future;
}

// ══════════════════════════════════════════════════
// 액션 실행 (다이얼로그 분기)
// ══════════════════════════════════════════════════

Future<bool?> _executeAction({
  required BuildContext context,
  required WidgetRef ref,
  required ItemData item,
  required StatusAction action,
}) async {
  // 정산 전이 — sale 레코드에 saleDate/settledAt 자동 설정
  if (action.targetStatus == 'SETTLED' || action.targetStatus == 'DEFECT_SETTLED') {
    return _confirmAndSettle(
      context: context,
      ref: ref,
      item: item,
      action: action,
    );
  }

  // 단순 전이 (추가 입력 불필요)
  // 판매/발송 통합 처리 (LISTED → OUTGOING)
  if (action.needsSellAndShip) {
    return _showSellAndShipDialog(context: context, ref: ref, item: item);
  }

  if (!action.needsShipment &&
      !action.needsInspection &&
      !action.needsRepair &&
      !action.needsRepairComplete &&
      !action.needsCancel &&
      !action.needsReturn &&
      !action.needsListing &&
      !action.needsSellPrice) {
    return _confirmAndTransition(
      context: context,
      ref: ref,
      item: item,
      action: action,
    );
  }

  // 리스팅 등록
  if (action.needsListing) {
    return _showListingDialog(context: context, ref: ref, item: item);
  }

  // 판매 확정 (실판매가 입력)
  if (action.needsSellPrice) {
    return _showSellPriceDialog(context: context, ref: ref, item: item);
  }

  // 발송 처리
  if (action.needsShipment) {
    return _showShipmentDialog(context: context, ref: ref, item: item);
  }

  // 검수 반려
  if (action.needsInspection) {
    return _showInspectionDialog(
      context: context,
      ref: ref,
      item: item,
      targetStatus: action.targetStatus,
      defectType: action.defectType!,
    );
  }

  // 수선 시작
  if (action.needsRepair) {
    return _showRepairStartDialog(context: context, ref: ref, item: item);
  }

  // 수선 완료
  if (action.needsRepairComplete) {
    return _showRepairCompleteDialog(
      context: context,
      ref: ref,
      item: item,
      targetStatus: action.targetStatus,
      outcome: action.repairOutcome!,
      needsReturn: action.needsReturn,
    );
  }

  // 주문 취소
  if (action.needsCancel) {
    return _showCancelDialog(context: context, ref: ref, item: item);
  }

  // 공급처 반품
  if (action.needsReturn) {
    return _showReturnDialog(
      context: context,
      ref: ref,
      item: item,
      targetStatus: action.targetStatus,
    );
  }

  return null;
}

// ══════════════════════════════════════════════════
// 단순 전이 확인
// ══════════════════════════════════════════════════

Future<bool?> _confirmAndTransition({
  required BuildContext context,
  required WidgetRef ref,
  required ItemData item,
  required StatusAction action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(action.label),
      content: Text('${_statusLabel(item.currentStatus)} → ${_statusLabel(action.targetStatus)}(으)로 변경하시겠습니까?'),
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

  if (confirmed != true) return false;

  await ref
      .read(itemDaoProvider)
      .updateStatus(item.id, action.targetStatus, note: action.label);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${action.label} 완료')),
    );
  }
  return true;
}

// ══════════════════════════════════════════════════
// 정산 전이 (saleDate + settledAt 자동 설정)
// ══════════════════════════════════════════════════

Future<bool?> _confirmAndSettle({
  required BuildContext context,
  required WidgetRef ref,
  required ItemData item,
  required StatusAction action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(action.label),
      content: Text(
          '${_statusLabel(item.currentStatus)} → ${_statusLabel(action.targetStatus)}(으)로 변경하시겠습니까?'),
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

  if (confirmed != true) return false;

  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // sale 레코드에 판매일 + 정산일 설정
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
      .updateStatus(item.id, action.targetStatus, note: action.label);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${action.label} 완료')),
    );
  }
  return true;
}

// ══════════════════════════════════════════════════
// 발송 처리 다이얼로그
// ══════════════════════════════════════════════════

Future<bool?> _showShipmentDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ItemData item,
}) async {
  final trackingCtrl = TextEditingController();
  final platformCtrl = TextEditingController();
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('발송 처리'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: trackingCtrl,
            decoration: const InputDecoration(
              labelText: '운송장 번호',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: platformCtrl,
            decoration: const InputDecoration(
              labelText: '플랫폼 (선택)',
              border: OutlineInputBorder(),
              hintText: '예: POIZON',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소')),
        FilledButton(
          onPressed: () async {
            if (trackingCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('운송장 번호를 입력하세요')),
              );
              return;
            }

            // 배송 레코드 생성
            await ref.read(subRecordDaoProvider).addShipment(
                  ShipmentsCompanion(
                    id: Value(_uuid.v4()),
                    itemId: Value(item.id),
                    seq: const Value(0), // 자동 생성됨
                    trackingNumber: Value(trackingCtrl.text.trim()),
                    outgoingDate: Value(today),
                    platform: Value(platformCtrl.text.isNotEmpty
                        ? platformCtrl.text.trim()
                        : null),
                    createdAt: Value(DateTime.now().toIso8601String()),
                  ),
                );

            // 상태 전이
            await ref
                .read(itemDaoProvider)
                .updateStatus(item.id, 'OUTGOING', note: '발송 처리');

            if (ctx.mounted) Navigator.pop(ctx, true);
          },
          child: const Text('발송'),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════
// 검수 반려 다이얼로그
// ══════════════════════════════════════════════════

Future<bool?> _showInspectionDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ItemData item,
  required String targetStatus,
  required String defectType,
}) async {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _InspectionSheet(
      ref: ref,
      item: item,
      targetStatus: targetStatus,
      defectType: defectType,
    ),
  );
}

class _InspectionSheet extends StatefulWidget {
  final WidgetRef ref;
  final ItemData item;
  final String targetStatus;
  final String defectType;

  const _InspectionSheet({
    required this.ref,
    required this.item,
    required this.targetStatus,
    required this.defectType,
  });

  @override
  State<_InspectionSheet> createState() => _InspectionSheetState();
}

class _InspectionSheetState extends State<_InspectionSheet> {
  final _reasonCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _photoUrls = <String>[];
  final _picker = ImagePicker();
  bool _submitting = false;

  String get _defectLabel => switch (widget.defectType) {
        'DEFECT_SALE' => '불량 판매',
        'DEFECT_HELD' => '불량 보류',
        'DEFECT_RETURN' => '반송',
        'PLATFORM_CANCEL' => '플랫폼 취소',
        _ => widget.defectType,
      };

  Color get _accentColor => switch (widget.defectType) {
        'DEFECT_SALE' => AppColors.warning,
        'DEFECT_HELD' => AppColors.statusDefectHeld,
        'DEFECT_RETURN' => AppColors.error,
        'PLATFORM_CANCEL' => AppColors.accent,
        _ => AppColors.primary,
      };

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _memoCtrl.dispose();
    _discountCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file != null) {
      setState(() => _photoUrls.add(file.path));
    }
  }

  Future<void> _pickFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file != null) {
      setState(() => _photoUrls.add(file.path));
    }
  }

  void _addUrl() {
    final url = _urlCtrl.text.trim();
    if (url.isNotEmpty) {
      setState(() {
        _photoUrls.add(url);
        _urlCtrl.clear();
      });
    }
  }

  void _removePhoto(int index) {
    setState(() => _photoUrls.removeAt(index));
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await widget.ref.read(subRecordDaoProvider).addInspectionRejection(
          InspectionRejectionsCompanion(
            id: Value(_uuid.v4()),
            itemId: Value(widget.item.id),
            returnSeq: const Value(0),
            rejectedAt: Value(today),
            reason: Value(
                _reasonCtrl.text.isNotEmpty ? _reasonCtrl.text : null),
            defectType: Value(widget.defectType),
            discountAmount: Value(int.tryParse(_discountCtrl.text)),
            photoUrls: Value(
                _photoUrls.isNotEmpty ? jsonEncode(_photoUrls) : null),
            memo: Value(_memoCtrl.text.isNotEmpty ? _memoCtrl.text : null),
            createdAt: Value(DateTime.now().toIso8601String()),
          ),
        );

    await widget.ref
        .read(itemDaoProvider)
        .updateStatus(widget.item.id, widget.targetStatus,
            note: '검수 반려 ($_defectLabel)');

    if (widget.targetStatus == 'POIZON_STORAGE') {
      await widget.ref.read(itemDaoProvider).updateItem(
            widget.item.id,
            ItemsCompanion(
              poizonStorageFrom:
                  Value(DateFormat('yyyy-MM-dd').format(DateTime.now())),
            ),
          );
    }

    if (mounted) Navigator.pop(context, true);
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
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '하자 판정',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _accentColor,
                          ),
                    ),
                  ),
                  Chip(
                    label: Text(_defectLabel,
                        style: TextStyle(fontSize: 11, color: _accentColor)),
                    backgroundColor: _accentColor.withAlpha(20),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
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
                  // 하자 사유
                  TextField(
                    controller: _reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: '하자 사유 *',
                      hintText: '예) 박스 찢김, 신발 오염, 사이즈 불일치 등',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),

                  if (widget.defectType == 'DEFECT_SALE') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _discountCtrl,
                      decoration: const InputDecoration(
                        labelText: '할인 금액 (원)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.discount_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 하자 사진 섹션
                  Text('하자 사진',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),

                  // 사진 미리보기
                  if (_photoUrls.isNotEmpty)
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photoUrls.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final url = _photoUrls[i];
                          final isFile = !url.startsWith('http');
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: isFile
                                    ? Image.file(File(url),
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                          width: 80,
                                          height: 80,
                                          color: AppColors.surfaceVariant,
                                          child: const Icon(
                                              Icons.broken_image,
                                              size: 24),
                                        ))
                                    : Image.network(url,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                          width: 80,
                                          height: 80,
                                          color: AppColors.surfaceVariant,
                                          child: const Icon(
                                              Icons.broken_image,
                                              size: 24),
                                        )),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removePhoto(i),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close,
                                        size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 8),

                  // 사진 추가 버튼
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickPhoto,
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: const Text('촬영', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: const Text('갤러리', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // URL 입력
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlCtrl,
                          decoration: const InputDecoration(
                            hintText: '이미지 URL 입력 후 추가',
                            isDense: true,
                            prefixIcon:
                                Icon(Icons.link, size: 18),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 10),
                          ),
                          onSubmitted: (_) => _addUrl(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _addUrl,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        child: const Text('추가', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 메모
                  TextField(
                    controller: _memoCtrl,
                    decoration: const InputDecoration(
                      labelText: '메모 (선택)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // 하단 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                            backgroundColor: _accentColor),
                        child: Text(_submitting
                            ? '처리 중...'
                            : '하자 판정 확정'),
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
}

// ══════════════════════════════════════════════════
// 수선 시작 다이얼로그
// ══════════════════════════════════════════════════

Future<bool?> _showRepairStartDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ItemData item,
}) async {
  final noteCtrl = TextEditingController();
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('수선 시작'),
      content: TextField(
        controller: noteCtrl,
        decoration: const InputDecoration(
          labelText: '수선 메모 (선택)',
          border: OutlineInputBorder(),
        ),
        maxLines: 2,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소')),
        FilledButton(
          onPressed: () async {
            await ref.read(subRecordDaoProvider).insertRepair(
                  RepairsCompanion(
                    id: Value(_uuid.v4()),
                    itemId: Value(item.id),
                    startedAt: Value(today),
                    repairNote: Value(
                        noteCtrl.text.isNotEmpty ? noteCtrl.text : null),
                    createdAt: Value(DateTime.now().toIso8601String()),
                  ),
                );

            await ref
                .read(itemDaoProvider)
                .updateStatus(item.id, 'REPAIRING', note: '수선 시작');

            if (ctx.mounted) Navigator.pop(ctx, true);
          },
          child: const Text('시작'),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════
// 수선 완료 다이얼로그
// ══════════════════════════════════════════════════

Future<bool?> _showRepairCompleteDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ItemData item,
  required String targetStatus,
  required String outcome,
  required bool needsReturn,
}) async {
  final costCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  // 반품용
  final returnReasonCtrl = TextEditingController();

  final outcomeLabel = switch (outcome) {
    'RELISTED' => '재등록',
    'SUPPLIER_RETURN' => '공급처 반품',
    'DISPOSED' => '폐기',
    'PERSONAL' => '개인 전환',
    _ => outcome,
  };

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('수선 완료 → $outcomeLabel'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: costCtrl,
              decoration: const InputDecoration(
                labelText: '수선 비용 (원, 선택)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                border: OutlineInputBorder(),
              ),
            ),
            if (needsReturn) ...[
              const SizedBox(height: 12),
              TextField(
                controller: returnReasonCtrl,
                decoration: const InputDecoration(
                  labelText: '반품 사유',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소')),
        FilledButton(
          onPressed: () async {
            // 가장 최근 수선 기록 완료 처리
            final repairs =
                await ref.read(subRecordDaoProvider).getRepairs(item.id);
            if (repairs.isNotEmpty) {
              final latest = repairs.first; // desc 정렬이므로 first가 최신
              await ref.read(subRecordDaoProvider).completeRepair(
                    latest.id,
                    outcome,
                    int.tryParse(costCtrl.text),
                    noteCtrl.text.isNotEmpty ? noteCtrl.text : null,
                  );
            }

            // 반품 레코드
            if (needsReturn) {
              await ref.read(subRecordDaoProvider).insertSupplierReturn(
                    SupplierReturnsCompanion(
                      id: Value(_uuid.v4()),
                      itemId: Value(item.id),
                      returnedAt: Value(DateFormat('yyyy-MM-dd')
                          .format(DateTime.now())),
                      reason: Value(returnReasonCtrl.text.isNotEmpty
                          ? returnReasonCtrl.text
                          : null),
                      createdAt:
                          Value(DateTime.now().toIso8601String()),
                    ),
                  );
            }

            // 상태 전이
            await ref.read(itemDaoProvider).updateStatus(
                item.id, targetStatus,
                note: '수선 완료 → $outcomeLabel');

            if (ctx.mounted) Navigator.pop(ctx, true);
          },
          child: const Text('완료'),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════
// 주문 취소 다이얼로그
// ══════════════════════════════════════════════════

Future<bool?> _showCancelDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ItemData item,
}) async {
  final reasonCtrl = TextEditingController();

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('주문 취소'),
      content: TextField(
        controller: reasonCtrl,
        decoration: const InputDecoration(
          labelText: '취소 사유',
          border: OutlineInputBorder(),
        ),
        maxLines: 2,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('돌아가기')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            await ref.read(subRecordDaoProvider).insertOrderCancellation(
                  OrderCancellationsCompanion(
                    id: Value(_uuid.v4()),
                    itemId: Value(item.id),
                    cancelledAt: Value(
                        DateFormat('yyyy-MM-dd').format(DateTime.now())),
                    reason: Value(reasonCtrl.text.isNotEmpty
                        ? reasonCtrl.text
                        : null),
                    createdAt: Value(DateTime.now().toIso8601String()),
                  ),
                );

            await ref
                .read(itemDaoProvider)
                .updateStatus(item.id, 'ORDER_CANCELLED', note: '주문 취소');

            if (ctx.mounted) Navigator.pop(ctx, true);
          },
          child: const Text('취소 확인'),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════
// 공급처 반품 다이얼로그
// ══════════════════════════════════════════════════

Future<bool?> _showReturnDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ItemData item,
  required String targetStatus,
}) async {
  final reasonCtrl = TextEditingController();
  final memoCtrl = TextEditingController();

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('공급처 반품'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(
              labelText: '반품 사유',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: memoCtrl,
            decoration: const InputDecoration(
              labelText: '메모 (선택)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소')),
        FilledButton(
          onPressed: () async {
            await ref.read(subRecordDaoProvider).insertSupplierReturn(
                  SupplierReturnsCompanion(
                    id: Value(_uuid.v4()),
                    itemId: Value(item.id),
                    returnedAt: Value(
                        DateFormat('yyyy-MM-dd').format(DateTime.now())),
                    reason: Value(reasonCtrl.text.isNotEmpty
                        ? reasonCtrl.text
                        : null),
                    memo: Value(
                        memoCtrl.text.isNotEmpty ? memoCtrl.text : null),
                    createdAt: Value(DateTime.now().toIso8601String()),
                  ),
                );

            await ref
                .read(itemDaoProvider)
                .updateStatus(item.id, targetStatus, note: '공급처 반품');

            if (ctx.mounted) Navigator.pop(ctx, true);
          },
          child: const Text('반품 처리'),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════
// 리스팅 등록 다이얼로그 (OFFICE_STOCK → LISTED)
// ══════════════════════════════════════════════════

const _platforms = ['POIZON', 'KREAM', 'SOLDOUT', 'DIRECT', 'OTHER'];
const _platformLabels = {
  'POIZON': 'POIZON (득물)',
  'KREAM': 'KREAM',
  'SOLDOUT': 'SOLDOUT',
  'DIRECT': '직거래',
  'OTHER': '기타',
};

Future<bool?> _showListingDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ItemData item,
}) async {
  final listedPriceCtrl = TextEditingController();
  String platform = 'POIZON';

  return showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('리스팅 등록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: platform,
              decoration: const InputDecoration(
                labelText: '판매 플랫폼',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.storefront),
              ),
              items: _platforms
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(_platformLabels[p] ?? p),
                      ))
                  .toList(),
              onChanged: (v) => setDialogState(() => platform = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: listedPriceCtrl,
              decoration: const InputDecoration(
                labelText: '등록가 (원)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
            onPressed: () async {
              final listedPrice = int.tryParse(listedPriceCtrl.text);
              if (listedPrice == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('등록가를 입력하세요')),
                );
                return;
              }

              // Sale 레코드 생성 (등록가만, 실판매가는 아직 없음)
              final dao = ref.read(saleDaoProvider);
              final existingSale = await dao.getByItemId(item.id);

              if (existingSale != null) {
                // 기존 판매 레코드 업데이트
                await dao.updateSale(
                  existingSale.id,
                  SalesCompanion(
                    itemId: Value(item.id),
                    platform: Value(platform),
                    listedPrice: Value(listedPrice),
                    dataSource: const Value('manual'),
                  ),
                );
              } else {
                // 신규 판매 레코드 생성
                await dao.insertSale(SalesCompanion(
                  id: Value(_uuid.v4()),
                  itemId: Value(item.id),
                  platform: Value(platform),
                  listedPrice: Value(listedPrice),
                  dataSource: const Value('manual'),
                  createdAt: Value(DateTime.now().toIso8601String()),
                ));
              }

              // 상태 전이
              await ref
                  .read(itemDaoProvider)
                  .updateStatus(item.id, 'LISTED', note: '리스팅 등록 ($platform)');

              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('리스팅'),
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════
// 판매 확정 다이얼로그 (LISTED → SOLD)
// ══════════════════════════════════════════════════

Future<bool?> _showSellPriceDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ItemData item,
}) async {
  final sellPriceCtrl = TextEditingController();

  // 기존 Sale에서 등록가/플랫폼 로드
  final existingSale = await ref.read(saleDaoProvider).getByItemId(item.id);
  final platform = existingSale?.platform ?? '-';
  final listedPrice = existingSale?.listedPrice;

  // 등록가를 기본값으로 채워넣기
  if (listedPrice != null) {
    sellPriceCtrl.text = '$listedPrice';
  }

  if (!context.mounted) return null;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('판매 확정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 현재 리스팅 정보
          Card(
            color: Colors.teal.shade50,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(Icons.sell, size: 16, color: Colors.teal.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '$platform · 등록가 ${listedPrice != null ? NumberFormat('#,###').format(listedPrice) : '-'}원',
                    style: TextStyle(
                        fontSize: 13, color: Colors.teal.shade800),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: sellPriceCtrl,
            decoration: const InputDecoration(
              labelText: '실판매가 (원)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.payments),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소')),
        FilledButton(
          onPressed: () async {
            final sellPrice = int.tryParse(sellPriceCtrl.text);
            if (sellPrice == null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('판매가를 입력하세요')),
              );
              return;
            }

            // Sale 업데이트 (실판매가 + 수수료/정산금 자동 계산)
            if (existingSale != null) {
              final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
              await ref.read(saleDaoProvider).updateSale(
                    existingSale.id,
                    SalesCompanion(
                      itemId: Value(item.id),
                      platform: Value(existingSale.platform),
                      sellPrice: Value(sellPrice),
                      listedPrice: Value(existingSale.listedPrice),
                      saleDate: Value(today),
                      platformFeeRate: Value(existingSale.platformFeeRate),
                    ),
                  );
            }

            // 상태 전이
            await ref
                .read(itemDaoProvider)
                .updateStatus(item.id, 'SOLD', note: '판매 확정 (${NumberFormat('#,###').format(sellPrice)}원)');

            if (ctx.mounted) Navigator.pop(ctx, true);
          },
          child: const Text('판매 확정'),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════
// 판매/발송 통합 다이얼로그 (LISTED → OUTGOING)
// ══════════════════════════════════════════════════

Future<bool?> _showSellAndShipDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ItemData item,
}) async {
  final sellPriceCtrl = TextEditingController();
  final trackingCtrl = TextEditingController();
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String shipDate = today;

  // 기존 Sale에서 등록가/플랫폼 로드
  final existingSale = await ref.read(saleDaoProvider).getByItemId(item.id);
  final platform = existingSale?.platform ?? '-';
  final listedPrice = existingSale?.listedPrice;

  // 등록가를 기본값으로
  if (listedPrice != null) {
    sellPriceCtrl.text = '$listedPrice';
  }

  if (!context.mounted) return null;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('판매/발송 처리'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 현재 리스팅 정보
              Card(
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Icon(Icons.sell, size: 16, color: Colors.teal.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$platform · 등록가 ${listedPrice != null ? NumberFormat('#,###').format(listedPrice) : '-'}원',
                          style: TextStyle(
                              fontSize: 13, color: Colors.teal.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 실제 판매가
              TextField(
                controller: sellPriceCtrl,
                decoration: const InputDecoration(
                  labelText: '실제 판매가 (원)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              // 발송일
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      shipDate = DateFormat('yyyy-MM-dd').format(picked);
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '발송일',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(shipDate),
                ),
              ),
              const SizedBox(height: 12),
              // 운송장 번호
              TextField(
                controller: trackingCtrl,
                decoration: const InputDecoration(
                  labelText: '운송장 번호 (선택)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_shipping),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
            onPressed: () async {
              final sellPrice = int.tryParse(sellPriceCtrl.text);
              if (sellPrice == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('판매가를 입력하세요')),
                );
                return;
              }

              // 1. Sale 업데이트 (실판매가 + 수수료/정산금 자동 계산)
              if (existingSale != null) {
                await ref.read(saleDaoProvider).updateSale(
                      existingSale.id,
                      SalesCompanion(
                        itemId: Value(item.id),
                        platform: Value(existingSale.platform),
                        sellPrice: Value(sellPrice),
                        listedPrice: Value(existingSale.listedPrice),
                        saleDate: Value(shipDate),
                        outgoingDate: Value(shipDate),
                        trackingNumber: Value(trackingCtrl.text.isNotEmpty
                            ? trackingCtrl.text.trim()
                            : null),
                        platformFeeRate: Value(existingSale.platformFeeRate),
                      ),
                    );
              }

              // 2. Shipment 레코드 생성
              if (trackingCtrl.text.trim().isNotEmpty) {
                await ref.read(subRecordDaoProvider).addShipment(
                      ShipmentsCompanion(
                        id: Value(_uuid.v4()),
                        itemId: Value(item.id),
                        seq: const Value(0),
                        trackingNumber: Value(trackingCtrl.text.trim()),
                        outgoingDate: Value(shipDate),
                        platform: Value(existingSale?.platform),
                        createdAt: Value(DateTime.now().toIso8601String()),
                      ),
                    );
              }

              // 3. 상태 전이 LISTED → OUTGOING
              await ref.read(itemDaoProvider).updateStatus(
                  item.id, 'OUTGOING',
                  note:
                      '판매/발송 (${NumberFormat('#,###').format(sellPrice)}원)');

              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('발송'),
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════
// 유틸
// ══════════════════════════════════════════════════

String _statusLabel(String status) => switch (status) {
      'ORDER_PLACED' => '주문완료',
      'ORDER_CANCELLED' => '주문취소',
      'OFFICE_STOCK' => '사무실재고',
      'OUTGOING' => '발송중',
      'IN_INSPECTION' => '검수중',
      'LISTED' => '리스팅',
      'SOLD' => '판매완료',
      'SETTLED' => '정산완료',
      'RETURNING' => '반송중',
      'DEFECT_FOR_SALE' => '불량판매',
      'DEFECT_SOLD' => '불량판매완료',
      'DEFECT_SETTLED' => '불량정산',
      'DEFECT_HELD' => '불량보류',
      'REPAIRING' => '수선중',
      'POIZON_STORAGE' => '포이즌보관',
      'CANCEL_RETURNING' => '취소반송',
      'SUPPLIER_RETURN' => '공급처반품',
      'DISPOSED' => '폐기',
      'SAMPLE' => '샘플',
      _ => status,
    };
