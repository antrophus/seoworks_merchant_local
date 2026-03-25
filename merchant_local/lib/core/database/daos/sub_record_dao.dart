import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
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

const _uuid = Uuid();

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
            ..where((t) => t.itemId.equals(itemId))
            ..orderBy([(t) => OrderingTerm.desc(t.changedAt)]))
          .get();

  /// 최근 상태 변경 로그 (대시보드용)
  Future<List<StatusLogData>> getRecentStatusLogs({int limit = 8}) =>
      (select(statusLogs)
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
            ..where((t) => t.itemId.equals(itemId))
            ..orderBy([(t) => OrderingTerm.asc(t.returnSeq)]))
          .get();

  /// 검수 반려 등록 (순번 자동 생성)
  Future<void> addInspectionRejection(
      InspectionRejectionsCompanion entry) async {
    final itemId = entry.itemId.value;
    // MAX(return_seq) + 1
    final maxSeq = await customSelect(
      'SELECT COALESCE(MAX(return_seq), 0) as max_seq FROM inspection_rejections WHERE item_id = ?',
      variables: [Variable.withString(itemId)],
      readsFrom: {inspectionRejections},
    ).getSingle();
    final nextSeq = maxSeq.read<int>('max_seq') + 1;

    await into(inspectionRejections).insert(
      entry.copyWith(returnSeq: Value(nextSeq)),
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
            ..where((t) => t.itemId.equals(itemId))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .get();

  Future<void> insertRepair(RepairsCompanion entry) =>
      into(repairs).insert(entry);

  Future<void> completeRepair(
      String repairId, String outcome, int? cost, String? note) async {
    await (update(repairs)..where((t) => t.id.equals(repairId))).write(
      RepairsCompanion(
        completedAt: Value(DateTime.now().toIso8601String().substring(0, 10)),
        outcome: Value(outcome),
        repairCost: Value(cost),
        repairNote: Value(note),
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
            ..where((t) => t.itemId.equals(itemId))
            ..orderBy([(t) => OrderingTerm.asc(t.seq)]))
          .get();

  /// 배송 등록 (순번 자동 생성)
  Future<void> addShipment(ShipmentsCompanion entry) async {
    final itemId = entry.itemId.value;
    final maxSeq = await customSelect(
      'SELECT COALESCE(MAX(seq), 0) as max_seq FROM shipments WHERE item_id = ?',
      variables: [Variable.withString(itemId)],
      readsFrom: {shipments},
    ).getSingle();
    final nextSeq = maxSeq.read<int>('max_seq') + 1;

    await into(shipments).insert(
      entry.copyWith(seq: Value(nextSeq)),
    );
  }

  Future<void> insertAllShipments(List<ShipmentsCompanion> entries) async {
    await batch((b) {
      b.insertAll(shipments, entries, mode: InsertMode.insertOrIgnore);
    });
  }

  // ── SupplierReturns ──
  Future<void> insertSupplierReturn(SupplierReturnsCompanion entry) =>
      into(supplierReturns).insert(entry);

  Future<void> insertAllSupplierReturns(
      List<SupplierReturnsCompanion> entries) async {
    await batch((b) {
      b.insertAll(supplierReturns, entries, mode: InsertMode.insertOrIgnore);
    });
  }

  // ── OrderCancellations ──
  Future<void> insertOrderCancellation(OrderCancellationsCompanion entry) =>
      into(orderCancellations).insert(entry);

  Future<void> insertAllOrderCancellations(
      List<OrderCancellationsCompanion> entries) async {
    await batch((b) {
      b.insertAll(orderCancellations, entries,
          mode: InsertMode.insertOrIgnore);
    });
  }

  // ── SampleUsages ──
  Future<void> insertSampleUsage(SampleUsagesCompanion entry) =>
      into(sampleUsages).insert(entry);

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
