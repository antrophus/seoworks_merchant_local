import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/order_table.dart';

part 'order_dao.g.dart';

@DriftAccessor(tables: [PoizonOrders])
class OrderDao extends DatabaseAccessor<AppDatabase> with _$OrderDaoMixin {
  OrderDao(super.db);

  /// 전체 주문 목록
  Future<List<PoizonOrderData>> getAll() =>
      (select(poizonOrders)
            ..orderBy([(t) => OrderingTerm.desc(t.orderedAt)]))
          .get();

  /// 주문 스트림 (실시간 갱신)
  Stream<List<PoizonOrderData>> watchAll() =>
      (select(poizonOrders)
            ..orderBy([(t) => OrderingTerm.desc(t.orderedAt)]))
          .watch();

  /// 상태별 필터링
  Stream<List<PoizonOrderData>> watchByStatus(String status) =>
      (select(poizonOrders)
            ..where((t) => t.status.equals(status))
            ..orderBy([(t) => OrderingTerm.desc(t.orderedAt)]))
          .watch();

  /// ID로 조회
  Future<PoizonOrderData?> getById(String orderId) =>
      (select(poizonOrders)..where((t) => t.orderId.equals(orderId)))
          .getSingleOrNull();

  /// Upsert
  Future<void> upsert(PoizonOrdersCompanion entry) =>
      into(poizonOrders).insertOnConflictUpdate(entry);

  /// 일괄 Upsert
  Future<void> upsertAll(List<PoizonOrdersCompanion> entries) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(poizonOrders, entry, onConflict: DoUpdate((_) => entry));
      }
    });
  }
}
