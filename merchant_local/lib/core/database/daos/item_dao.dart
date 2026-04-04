import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../tables/item_table.dart';
import '../tables/product_table.dart';
import '../tables/status_log_table.dart';

part 'item_dao.g.dart';

const _uuid = Uuid();

/// 허용된 상태 전이 맵: 현재 상태 → 이동 가능한 상태 목록
const validTransitions = <String, Set<String>>{
  'ORDER_PLACED': {'OFFICE_STOCK', 'ORDER_CANCELLED'},
  'OFFICE_STOCK': {'LISTED', 'SUPPLIER_RETURN', 'SAMPLE', 'DISPOSED'},
  'LISTED': {'OUTGOING', 'OFFICE_STOCK', 'POIZON_STORAGE'},
  'SOLD': {'OUTGOING', 'LISTED'},
  'OUTGOING': {'IN_INSPECTION'},
  'IN_INSPECTION': {
    'SETTLED', 'DEFECT_FOR_SALE', 'DEFECT_HELD', 'RETURNING',
    'POIZON_STORAGE', 'CANCEL_RETURNING',
  },
  'SETTLED': {},
  'DEFECT_FOR_SALE': {'DEFECT_SOLD', 'REPAIRING'},
  'DEFECT_SOLD': {'DEFECT_SETTLED'},
  'DEFECT_SETTLED': {},
  'DEFECT_HELD': {'OFFICE_STOCK', 'REPAIRING', 'SUPPLIER_RETURN', 'DISPOSED'},
  'POIZON_STORAGE': {'SETTLED', 'CANCEL_RETURNING'},
  'CANCEL_RETURNING': {'OFFICE_STOCK'},
  'RETURNING': {'OFFICE_STOCK', 'REPAIRING'},
  'REPAIRING': {'OFFICE_STOCK', 'SUPPLIER_RETURN', 'DISPOSED', 'SAMPLE'},
  'SUPPLIER_RETURN': {},
  'DISPOSED': {},
  'SAMPLE': {},
  'ORDER_CANCELLED': {},
};

@DriftAccessor(tables: [Items, Products, StatusLogs])
class ItemDao extends DatabaseAccessor<AppDatabase> with _$ItemDaoMixin {
  ItemDao(super.db);

  /// 전체 아이템 목록
  Future<List<ItemData>> getAll() =>
      (select(items)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// 아이템 스트림
  Stream<List<ItemData>> watchAll() =>
      (select(items)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  /// 상태별 필터링
  Stream<List<ItemData>> watchByStatus(String status) =>
      (select(items)
            ..where((t) =>
                t.currentStatus.equals(status) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  /// 여러 상태로 필터링
  Stream<List<ItemData>> watchByStatuses(List<String> statuses) =>
      (select(items)
            ..where((t) =>
                t.currentStatus.isIn(statuses) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  /// ID로 조회
  Future<ItemData?> getById(String id) =>
      (select(items)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// ID로 스트림 조회 (실시간 변경 감지)
  Stream<ItemData?> watchById(String id) =>
      (select(items)..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// SKU로 조회
  Future<ItemData?> getBySku(String sku) =>
      (select(items)
            ..where((t) => t.sku.equals(sku) & t.isDeleted.equals(false)))
          .getSingleOrNull();

  /// 바코드로 조회
  Future<ItemData?> getByBarcode(String barcode) =>
      (select(items)
            ..where((t) =>
                t.barcode.equals(barcode) & t.isDeleted.equals(false)))
          .getSingleOrNull();

  /// 상품 모델별 조회
  Future<List<ItemData>> getByProductId(String productId) =>
      (select(items)
            ..where((t) =>
                t.productId.equals(productId) & t.isDeleted.equals(false))
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
          items.isPersonal.equals(false) &
          items.isDeleted.equals(false),
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
  /// [InvalidStatusTransitionException] — 허용되지 않는 전이 시 발생
  Future<void> updateStatus(String itemId, String newStatus,
      {String? note}) async {
    await transaction(() async {
      final item = await getById(itemId);
      if (item == null) {
        throw StateError('아이템을 찾을 수 없습니다: $itemId');
      }

      final oldStatus = item.currentStatus;

      // 상태 전이 검증
      final allowed = validTransitions[oldStatus];
      if (allowed != null && !allowed.contains(newStatus)) {
        throw InvalidStatusTransitionException(
          itemId: itemId,
          from: oldStatus,
          to: newStatus,
        );
      }
      final now = DateTime.now().toIso8601String();
      final hlcValue = db.hlcClock?.increment().toString() ?? '';

      // items 상태 업데이트
      await (update(items)..where((t) => t.id.equals(itemId))).write(
        ItemsCompanion(
          currentStatus: Value(newStatus),
          updatedAt: Value(now),
          hlc: Value(hlcValue),
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
        hlc: Value(db.hlcClock?.increment().toString() ?? ''),
      ));
    });
  }

  /// Insert
  Future<void> insertItem(ItemsCompanion entry) =>
      into(items).insert(
        entry.copyWith(hlc: Value(db.hlcClock?.increment().toString() ?? '')),
      );

  /// Update
  Future<void> updateItem(String id, ItemsCompanion entry) =>
      (update(items)..where((t) => t.id.equals(id))).write(
        entry.copyWith(hlc: Value(db.hlcClock?.increment().toString() ?? '')),
      );

  /// 일괄 Insert (데이터 임포트용)
  Future<void> insertAll(List<ItemsCompanion> entries) async {
    await batch((b) {
      b.insertAll(items, entries, mode: InsertMode.insertOrIgnore);
    });
  }

  /// SKU / 바코드 / 모델코드 검색
  Future<List<ItemData>> search(String query, {List<String>? statuses}) async {
    final pattern = '%$query%';
    final result = select(items).join([
      innerJoin(products, products.id.equalsExp(items.productId)),
    ]);
    var condition = (items.sku.like(pattern) |
            items.barcode.like(pattern) |
            products.modelCode.like(pattern) |
            products.modelName.like(pattern)) &
        items.isDeleted.equals(false);
    if (statuses != null && statuses.isNotEmpty) {
      condition = condition & items.currentStatus.isIn(statuses);
    }
    result.where(condition);
    result.orderBy([OrderingTerm.desc(items.createdAt)]);
    result.limit(50);
    final rows = await result.get();
    return rows.map((r) => r.readTable(items)).toList();
  }

  /// 동일 모델 + 동일 사이즈의 미정산 재고 수량
  Future<int> countByProductAndSize(String productId, String sizeKr) async {
    final result = await customSelect(
      "SELECT COUNT(*) AS cnt FROM items "
      "WHERE product_id = ? AND size_kr = ? AND current_status != 'SETTLED' AND is_deleted = 0",
      variables: [Variable.withString(productId), Variable.withString(sizeKr)],
      readsFrom: {items},
    ).getSingle();
    return result.read<int>('cnt');
  }

  /// 바코드 미등록 아이템 검색 (SKU / 모델코드 / 모델명)
  Future<List<ItemData>> searchWithoutBarcode(String query) async {
    final pattern = '%$query%';
    final result = select(items).join([
      innerJoin(products, products.id.equalsExp(items.productId)),
    ]);
    result.where(
      (items.barcode.isNull() | items.barcode.equals('')) &
          (items.sku.like(pattern) |
              products.modelCode.like(pattern) |
              products.modelName.like(pattern)) &
          items.isDeleted.equals(false),
    );
    result.orderBy([OrderingTerm.desc(items.createdAt)]);
    result.limit(30);
    final rows = await result.get();
    return rows.map((r) => r.readTable(items)).toList();
  }

  /// 상품(productId) 기준 전체 아이템 조회 (사이즈별 재고 등)
  Future<List<ItemData>> getAllByProductId(String productId) =>
      (select(items)
            ..where((t) =>
                t.productId.equals(productId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.sizeKr)]))
          .get();

  /// 대시보드 통계 — 상태별 카운트
  Future<Map<String, int>> getStatusCounts() async {
    final query = customSelect(
      'SELECT current_status, COUNT(*) as cnt FROM items WHERE is_deleted = 0 GROUP BY current_status',
      readsFrom: {items},
    );
    final results = await query.get();
    return {
      for (final row in results)
        row.read<String>('current_status'): row.read<int>('cnt'),
    };
  }

  /// 대시보드 — 브랜드 Top N (아이템 수 기준)
  Future<List<Map<String, dynamic>>> getTopBrands(int limit) async {
    final results = await customSelect(
      '''
      SELECT b.name AS brand_name, COUNT(*) AS cnt
      FROM items i
      INNER JOIN products p ON p.id = i.product_id
      INNER JOIN brands b ON b.id = p.brand_id
      WHERE i.current_status NOT IN ('ORDER_CANCELLED', 'DISPOSED')
        AND i.is_deleted = 0
      GROUP BY b.id, b.name
      ORDER BY cnt DESC
      LIMIT ?
      ''',
      variables: [Variable.withInt(limit)],
      readsFrom: {items},
    ).get();
    return results
        .map((r) => {
              'brandName': r.read<String>('brand_name'),
              'count': r.read<int>('cnt'),
            })
        .toList();
  }

  /// 대시보드 — 검수 기한 경과 아이템 수 (IN_INSPECTION 상태에서 N일 이상)
  /// updated_at = 상태가 IN_INSPECTION으로 변경된 시점
  Future<int> getOverdueInspectionCount(int days) async {
    final cutoff =
        DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final result = await customSelect(
      '''
      SELECT COUNT(*) AS cnt FROM items
      WHERE current_status = 'IN_INSPECTION'
        AND updated_at < ?
        AND is_deleted = 0
      ''',
      variables: [Variable.withString(cutoff)],
      readsFrom: {items},
    ).getSingle();
    return result.read<int>('cnt');
  }

  /// 대시보드 — 자산 개요 (실재고 기준)
  Future<Map<String, int>> getAssetSummary() async {
    // 1. 재고 자산 (현 보유 재고의 구매원가·등록가·미실현손익)
    final stock = await customSelect(
      '''
      SELECT
        COALESCE(SUM(p.purchase_price), 0) AS stock_cost,
        COALESCE(SUM(CASE WHEN s.listed_price IS NOT NULL
          THEN s.listed_price ELSE 0 END), 0) AS stock_listed,
        COALESCE(SUM(CASE WHEN s.listed_price IS NOT NULL
          THEN s.listed_price - COALESCE(p.purchase_price, 0)
          ELSE 0 END), 0) AS unrealized_profit
      FROM items i
      LEFT JOIN purchases p ON p.item_id = i.id AND p.is_deleted = 0
      LEFT JOIN sales s ON s.item_id = i.id AND s.is_deleted = 0
      WHERE i.current_status IN
        ('LISTED','POIZON_STORAGE','OUTGOING','IN_INSPECTION',
         'OFFICE_STOCK','RETURNING','REPAIRING')
        AND i.is_deleted = 0
      ''',
      readsFrom: {items},
    ).getSingle();

    // 2. 구매 합산 (전체 구매)
    final purchase = await customSelect(
      '''
      SELECT COUNT(*) AS cnt,
             COALESCE(SUM(p.purchase_price), 0) AS amt
      FROM purchases p
      JOIN items i ON i.id = p.item_id AND i.is_deleted = 0
      WHERE p.is_deleted = 0
      ''',
      readsFrom: {items},
    ).getSingle();

    // 거래처 반품 (supplier_returns 레코드 존재 OR 상태 기반)
    final ret = await customSelect(
      '''
      SELECT COUNT(*) AS cnt,
             COALESCE(SUM(p.purchase_price), 0) AS amt
      FROM items i
      JOIN purchases p ON p.item_id = i.id AND p.is_deleted = 0
      WHERE i.is_deleted = 0
        AND (
          EXISTS (SELECT 1 FROM supplier_returns sr WHERE sr.item_id = i.id)
          OR i.current_status IN ('RETURNING','SUPPLIER_RETURN','CANCEL_RETURNING')
        )
      ''',
      readsFrom: {items},
    ).getSingle();

    // 3. 정산 합산 (법인/개인 분리 + 실현 손익)
    final settle = await customSelect(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN i.is_personal = 0 THEN 1 ELSE 0 END), 0)
          AS corp_count,
        COALESCE(SUM(CASE WHEN i.is_personal = 1 THEN 1 ELSE 0 END), 0)
          AS personal_count,
        COALESCE(SUM(CASE WHEN i.is_personal = 0
          THEN s.settlement_amount ELSE 0 END), 0) AS corp_amount,
        COALESCE(SUM(CASE WHEN i.is_personal = 1
          THEN s.settlement_amount ELSE 0 END), 0) AS personal_amount,
        COALESCE(SUM(
          COALESCE(s.settlement_amount, 0) - COALESCE(p.purchase_price, 0)
        ), 0) AS realized_profit
      FROM items i
      JOIN sales s ON s.item_id = i.id AND s.is_deleted = 0
      LEFT JOIN purchases p ON p.item_id = i.id AND p.is_deleted = 0
      WHERE i.current_status IN ('SETTLED', 'DEFECT_SETTLED')
        AND i.is_deleted = 0
      ''',
      readsFrom: {items},
    ).getSingle();

    // 4. 부가세 환급 (정산 완료 제품의 VAT)
    final vat = await customSelect(
      '''
      SELECT COALESCE(CAST(ROUND(SUM(p.vat_refundable), 0) AS INTEGER), 0)
        AS vat_total
      FROM items i
      JOIN purchases p ON p.item_id = i.id AND p.is_deleted = 0
      WHERE i.current_status IN ('SETTLED', 'DEFECT_SETTLED')
        AND i.is_deleted = 0
      ''',
      readsFrom: {items},
    ).getSingle();

    return {
      'stockCost': stock.read<int>('stock_cost'),
      'stockListed': stock.read<int>('stock_listed'),
      'unrealizedProfit': stock.read<int>('unrealized_profit'),
      'purchaseCount': purchase.read<int>('cnt'),
      'purchaseAmount': purchase.read<int>('amt'),
      'returnCount': ret.read<int>('cnt'),
      'returnAmount': ret.read<int>('amt'),
      'corpCount': settle.read<int>('corp_count'),
      'personalCount': settle.read<int>('personal_count'),
      'corpAmount': settle.read<int>('corp_amount'),
      'personalAmount': settle.read<int>('personal_amount'),
      'realizedProfit': settle.read<int>('realized_profit'),
      'vatRefund': vat.read<int>('vat_total'),
    };
  }
}

/// 허용되지 않는 상태 전이 시 발생하는 예외
class InvalidStatusTransitionException implements Exception {
  final String itemId;
  final String from;
  final String to;

  const InvalidStatusTransitionException({
    required this.itemId,
    required this.from,
    required this.to,
  });

  @override
  String toString() =>
      'InvalidStatusTransitionException: $from → $to (item: $itemId)';
}
