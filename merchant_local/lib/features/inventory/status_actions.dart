import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';

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
    StatusAction('샘플 전환', 'SAMPLE', Icons.card_giftcard, Colors.pink),
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
  ],
  'LISTED': [
    StatusAction('판매 확정 (오퍼 수락)', 'SOLD', Icons.check_circle, Colors.green,
        needsSellPrice: true),
    StatusAction('리스팅 취소 (사무실 복귀)', 'OFFICE_STOCK', Icons.warehouse, Colors.blue),
  ],
  'SOLD': [
    StatusAction('발송', 'OUTGOING', Icons.local_shipping, Colors.indigo,
        needsShipment: true),
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

  return showModalBottomSheet<bool>(
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
                    if (result == true && context.mounted) {
                      // 호출한 곳에서 새로고침하도록 true 반환
                      // bottom sheet은 이미 닫혔으므로 별도 처리
                    }
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
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
  // 단순 전이 (추가 입력 불필요)
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
  final reasonCtrl = TextEditingController();
  final memoCtrl = TextEditingController();
  final discountCtrl = TextEditingController();
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final defectLabel = switch (defectType) {
    'DEFECT_SALE' => '불량 판매',
    'DEFECT_HELD' => '불량 보류',
    'DEFECT_RETURN' => '반송',
    _ => defectType,
  };

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('검수 반려 ($defectLabel)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: '반려 사유',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            if (defectType == 'DEFECT_SALE') ...[
              const SizedBox(height: 12),
              TextField(
                controller: discountCtrl,
                decoration: const InputDecoration(
                  labelText: '할인 금액 (원)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
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
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소')),
        FilledButton(
          onPressed: () async {
            // 검수 반려 레코드 생성
            await ref.read(subRecordDaoProvider).addInspectionRejection(
                  InspectionRejectionsCompanion(
                    id: Value(_uuid.v4()),
                    itemId: Value(item.id),
                    returnSeq: const Value(0), // 자동 생성
                    rejectedAt: Value(today),
                    reason: Value(reasonCtrl.text.isNotEmpty
                        ? reasonCtrl.text
                        : null),
                    defectType: Value(defectType),
                    discountAmount: Value(int.tryParse(discountCtrl.text)),
                    memo: Value(
                        memoCtrl.text.isNotEmpty ? memoCtrl.text : null),
                    createdAt: Value(DateTime.now().toIso8601String()),
                  ),
                );

            // 상태 전이
            await ref
                .read(itemDaoProvider)
                .updateStatus(item.id, targetStatus, note: '검수 반려 ($defectLabel)');

            if (ctx.mounted) Navigator.pop(ctx, true);
          },
          child: const Text('확인'),
        ),
      ],
    ),
  );
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
      'SUPPLIER_RETURN' => '공급처반품',
      'DISPOSED' => '폐기',
      'SAMPLE' => '샘플',
      _ => status,
    };
