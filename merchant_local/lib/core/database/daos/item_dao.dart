import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../tables/item_table.dart';
import '../tables/product_table.dart';
import '../tables/status_log_table.dart';

part 'item_dao.g.dart';

const _uuid = Uuid();

@DriftAccessor(tables: [Items, Products, StatusLogs])
class ItemDao extends DatabaseAccessor<AppDatabase> with _$ItemDaoMixin {
  ItemDao(super.db);

  /// 전체 아이템 목록
  Future<List<ItemData>> getAll() =>
      (select(items)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  /// 아이템 스트림
  Stream<List<ItemData>> watchAll() =>
      (select(items)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  /// 상태별 필터링
  Stream<List<ItemData>> watchByStatus(String status) =>
      (select(items)
            ..where((t) => t.currentStatus.equals(status))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  /// 여러 상태로 필터링
  Stream<List<ItemData>> watchByStatuses(List<String> statuses) =>
      (select(items)
            ..where((t) => t.currentStatus.isIn(statuses))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  /// ID로 조회
  Future<ItemData?> getById(String id) =>
      (select(items)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// SKU로 조회
  Future<ItemData?> getBySku(String sku) =>
      (select(items)..where((t) => t.sku.equals(sku))).getSingleOrNull();

  /// 바코드로 조회
  Future<ItemData?> getByBarcode(String barcode) =>
      (select(items)..where((t) => t.barcode.equals(barcode)))
          .getSingleOrNull();

  /// 상품 모델별 조회
  Future<List<ItemData>> getByProductId(String productId) =>
      (select(items)
            ..where((t) => t.productId.equals(productId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  /// FIFO 재고 조회
  Future<ItemData?> getFifoItem(String modelCode, {String? sizeKr}) async {
    final query = select(items).join([
      innerJoin(products, products.id.equalsExp(items.productId)),
    ]);
    query.where(
      products.modelCode.equals(modelCode) &
          items.currentStatus.equals('OFFICE_STOCK') &
          items.isPersonal.equals(false),
    );
    if (sizeKr != null) {
      query.where(items.sizeKr.equals(sizeKr));
    }
    query.orderBy([OrderingTerm.asc(items.createdAt)]);
    query.limit(1);

    final result = await query.getSingleOrNull();
    return result?.readTable(items);
  }

  /// 상태 변경 + 로그 자동 기록 (트랜잭션)
  Future<void> updateStatus(String itemId, String newStatus,
      {String? note}) async {
    await transaction(() async {
      final item = await getById(itemId);
      if (item == null) return;

      final oldStatus = item.currentStatus;
      final now = DateTime.now().toIso8601String();

      // items 상태 업데이트
      await (update(items)..where((t) => t.id.equals(itemId))).write(
        ItemsCompanion(
          currentStatus: Value(newStatus),
          updatedAt: Value(now),
        ),
      );

      // status_logs 기록
      await into(statusLogs).insert(StatusLogsCompanion.insert(
        id: _uuid.v4(),
        itemId: itemId,
        oldStatus: Value(oldStatus),
        newStatus: newStatus,
        note: Value(note),
        changedAt: Value(now),
      ));
    });
  }

  /// Insert
  Future<void> insertItem(ItemsCompanion entry) =>
      into(items).insert(entry);

  /// Update
  Future<void> updateItem(String id, ItemsCompanion entry) =>
      (update(items)..where((t) => t.id.equals(id))).write(entry);

  /// 일괄 Insert (데이터 임포트용)
  Future<void> insertAll(List<ItemsCompanion> entries) async {
    await batch((b) {
      b.insertAll(items, entries, mode: InsertMode.insertOrIgnore);
    });
  }

  /// SKU / 바코드 / 모델코드 검색
  Future<List<ItemData>> search(String query) async {
    final pattern = '%$query%';
    final result = select(items).join([
      innerJoin(products, products.id.equalsExp(items.productId)),
    ]);
    result.where(
      items.sku.like(pattern) |
          items.barcode.like(pattern) |
          products.modelCode.like(pattern) |
          products.modelName.like(pattern),
    );
    result.orderBy([OrderingTerm.desc(items.createdAt)]);
    result.limit(50);
    final rows = await result.get();
    return rows.map((r) => r.readTable(items)).toList();
  }

  /// 상품(productId) 기준 전체 아이템 조회 (사이즈별 재고 등)
  Future<List<ItemData>> getAllByProductId(String productId) =>
      (select(items)
            ..where((t) => t.productId.equals(productId))
            ..orderBy([(t) => OrderingTerm.asc(t.sizeKr)]))
          .get();

  /// 대시보드 통계 — 상태별 카운트
  Future<Map<String, int>> getStatusCounts() async {
    final query = customSelect(
      'SELECT current_status, COUNT(*) as cnt FROM items GROUP BY current_status',
      readsFrom: {items},
    );
    final results = await query.get();
    return {
      for (final row in results)
        row.read<String>('current_status'): row.read<int>('cnt'),
    };
  }
}
