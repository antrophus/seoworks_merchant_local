import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/status_log_table.dart';
import '../tables/inspection_rejection_table.dart';
import '../tables/repair_table.dart';
import '../tables/shipment_table.dart';
import '../tables/supplier_return_table.dart';
import '../tables/order_cancellation_table.dart';
import '../tables/sample_usage_table.dart';
import '../tables/poizon_sync_log_table.dart';

part 'sub_record_dao.g.dart';


/// 부속 기록 DAO (상태로그, 검수반려, 수선, 배송, 반품, 취소, 샘플, 동기화로그)
@DriftAccessor(tables: [
  StatusLogs,
  InspectionRejections,
  Repairs,
  Shipments,
  SupplierReturns,
  OrderCancellations,
  SampleUsages,
  PoizonSyncLogs,
])
class SubRecordDao extends DatabaseAccessor<AppDatabase>
    with _$SubRecordDaoMixin {
  SubRecordDao(super.db);

  // ── StatusLogs ──
  Future<List<StatusLogData>> getStatusLogs(String itemId) =>
      (select(statusLogs)
            ..where((t) =>
                t.itemId.equals(itemId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.changedAt)]))
          .get();

  /// 최근 상태 변경 로그 (대시보드용)
  Future<List<StatusLogData>> getRecentStatusLogs({int limit = 8}) =>
      (select(statusLogs)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.changedAt)])
            ..limit(limit))
          .get();

  Future<void> insertAllStatusLogs(List<StatusLogsCompanion> entries) async {
    await batch((b) {
      b.insertAll(statusLogs, entries, mode: InsertMode.insertOrIgnore);
    });
  }

  // ── InspectionRejections ──
  Future<List<InspectionRejectionData>> getInspectionRejections(
          String itemId) =>
      (select(inspectionRejections)
            ..where((t) =>
                t.itemId.equals(itemId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.returnSeq)]))
          .get();

  /// 검수 반려 등록 (순번 자동 생성)
  Future<void> addInspectionRejection(
      InspectionRejectionsCompanion entry) async {
    final itemId = entry.itemId.value;
    // MAX(return_seq) + 1 — 삭제되지 않은 항목 기준
    final maxSeq = await customSelect(
      'SELECT COALESCE(MAX(return_seq), 0) as max_seq FROM inspection_rejections WHERE item_id = ? AND is_deleted = 0',
      variables: [Variable.withString(itemId)],
      readsFrom: {inspectionRejections},
    ).getSingle();
    final nextSeq = maxSeq.read<int>('max_seq') + 1;

    await into(inspectionRejections).insert(
      entry.copyWith(
        returnSeq: Value(nextSeq),
        hlc: Value(db.hlcClock?.increment().toString() ?? ''),
      ),
    );
  }

  /// 검수 반려 수정 (사진, 사유, 메모 등)
  Future<void> updateInspectionRejection(
      String id, InspectionRejectionsCompanion entry) async {
    await (update(inspectionRejections)..where((t) => t.id.equals(id))).write(
      entry.copyWith(hlc: Value(db.hlcClock?.increment().toString() ?? '')),
    );
  }

  Future<void> insertAllInspectionRejections(
      List<InspectionRejectionsCompanion> entries) async {
    await batch((b) {
      b.insertAll(inspectionRejections, entries,
          mode: InsertMode.insertOrIgnore);
    });
  }

  // ── Repairs ──
  Future<List<RepairData>> getRepairs(String itemId) =>
      (select(repairs)
            ..where((t) =>
                t.itemId.equals(itemId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .get();

  Future<void> insertRepair(RepairsCompanion entry) =>
      into(repairs).insert(
        entry.copyWith(hlc: Value(db.hlcClock?.increment().toString() ?? '')),
      );

  Future<void> completeRepair(
      String repairId, String outcome, int? cost, String? note) async {
    await (update(repairs)..where((t) => t.id.equals(repairId))).write(
      RepairsCompanion(
        completedAt: Value(DateTime.now().toIso8601String().substring(0, 10)),
        outcome: Value(outcome),
        repairCost: Value(cost),
        repairNote: Value(note),
        hlc: Value(db.hlcClock?.increment().toString() ?? ''),
      ),
    );
  }

  Future<void> insertAllRepairs(List<RepairsCompanion> entries) async {
    await batch((b) {
      b.insertAll(repairs, entries, mode: InsertMode.insertOrIgnore);
    });
  }

  // ── Shipments ──
  Future<List<ShipmentData>> getShipments(String itemId) =>
      (select(shipments)
            ..where((t) =>
                t.itemId.equals(itemId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.seq)]))
          .get();

  /// 배송 등록 (순번 자동 생성)
  Future<void> addShipment(ShipmentsCompanion entry) async {
    final itemId = entry.itemId.value;
    // MAX(seq) + 1 — 삭제되지 않은 항목 기준
    final maxSeq = await customSelect(
      'SELECT COALESCE(MAX(seq), 0) as max_seq FROM shipments WHERE item_id = ? AND is_deleted = 0',
      variables: [Variable.withString(itemId)],
      readsFrom: {shipments},
    ).getSingle();
    final nextSeq = maxSeq.read<int>('max_seq') + 1;

    await into(shipments).insert(
      entry.copyWith(
        seq: Value(nextSeq),
        hlc: Value(db.hlcClock?.increment().toString() ?? ''),
      ),
    );
  }

  Future<void> insertAllShipments(List<ShipmentsCompanion> entries) async {
    await batch((b) {
      b.insertAll(shipments, entries, mode: InsertMode.insertOrIgnore);
    });
  }

  /// 해당 아이템의 모든 배송 이력 날짜를 일괄 업데이트
  Future<void> updateShipmentsOutgoingDate(
      String itemId, String outgoingDate) async {
    await (update(shipments)..where((t) => t.itemId.equals(itemId))).write(
      ShipmentsCompanion(
        outgoingDate: Value(outgoingDate),
        hlc: Value(db.hlcClock?.increment().toString() ?? ''),
      ),
    );
  }

  /// 동일 운송장 번호의 모든 배송 이력 날짜를 일괄 업데이트
  Future<void> updateShipmentsOutgoingDateByTracking(
      String trackingNumber, String outgoingDate) async {
    await (update(shipments)
          ..where((t) => t.trackingNumber.equals(trackingNumber)))
        .write(
      ShipmentsCompanion(
        outgoingDate: Value(outgoingDate),
        hlc: Value(db.hlcClock?.increment().toString() ?? ''),
      ),
    );
  }

  /// 운송장 번호로 shipment 조회
  Future<List<ShipmentData>> getShipmentsByTracking(
      String trackingNumber) async {
    return (select(shipments)
          ..where((t) =>
              t.trackingNumber.equals(trackingNumber) &
              t.isDeleted.equals(false)))
        .get();
  }

  /// 중복 shipment 정리: 동일 item_id + tracking_number 조합에서
  /// 최신(seq가 가장 큰) 레코드만 유지하고 나머지 삭제
  Future<int> cleanupDuplicateShipments() async {
    final result = await customSelect(
      '''
      SELECT id FROM shipments
      WHERE is_deleted = 0
        AND id NOT IN (
        SELECT id FROM (
          SELECT id, ROW_NUMBER() OVER (
            PARTITION BY item_id, tracking_number
            ORDER BY seq DESC
          ) AS rn
          FROM shipments
          WHERE is_deleted = 0
        ) sub
        WHERE rn = 1
      )
      ''',
      readsFrom: {shipments},
    ).get();

    if (result.isEmpty) return 0;

    final idsToDelete = result.map((r) => r.read<String>('id')).toList();
    final hlcValue = db.hlcClock?.increment().toString() ?? '';
    await (update(shipments)..where((t) => t.id.isIn(idsToDelete))).write(
      ShipmentsCompanion(
        isDeleted: const Value(true),
        hlc: Value(hlcValue),
      ),
    );
    return idsToDelete.length;
  }

  /// 개별 shipment 소프트 삭제
  Future<void> deleteShipment(String id) async {
    await (update(shipments)..where((t) => t.id.equals(id))).write(
      ShipmentsCompanion(
        isDeleted: const Value(true),
        hlc: Value(db.hlcClock?.increment().toString() ?? ''),
      ),
    );
  }

  // ── SupplierReturns ──
  Future<void> insertSupplierReturn(SupplierReturnsCompanion entry) =>
      into(supplierReturns).insert(
        entry.copyWith(hlc: Value(db.hlcClock?.increment().toString() ?? '')),
      );

  Future<void> insertAllSupplierReturns(
      List<SupplierReturnsCompanion> entries) async {
    await batch((b) {
      b.insertAll(supplierReturns, entries, mode: InsertMode.insertOrIgnore);
    });
  }

  // ── OrderCancellations ──
  Future<void> insertOrderCancellation(OrderCancellationsCompanion entry) =>
      into(orderCancellations).insert(
        entry.copyWith(hlc: Value(db.hlcClock?.increment().toString() ?? '')),
      );

  Future<void> insertAllOrderCancellations(
      List<OrderCancellationsCompanion> entries) async {
    await batch((b) {
      b.insertAll(orderCancellations, entries,
          mode: InsertMode.insertOrIgnore);
    });
  }

  // ── SampleUsages ──
  Future<void> insertSampleUsage(SampleUsagesCompanion entry) =>
      into(sampleUsages).insert(
        entry.copyWith(hlc: Value(db.hlcClock?.increment().toString() ?? '')),
      );

  Future<void> insertAllSampleUsages(
      List<SampleUsagesCompanion> entries) async {
    await batch((b) {
      b.insertAll(sampleUsages, entries, mode: InsertMode.insertOrIgnore);
    });
  }

  // ── PoizonSyncLogs ──
  Future<void> insertSyncLog(PoizonSyncLogsCompanion entry) =>
      into(poizonSyncLogs).insert(entry);

  Future<List<PoizonSyncLogData>> getRecentSyncLogs({int limit = 20}) =>
      (select(poizonSyncLogs)
            ..orderBy([(t) => OrderingTerm.desc(t.syncedAt)])
            ..limit(limit))
          .get();
}
