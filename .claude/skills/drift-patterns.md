---
name: drift-patterns
description: 이 프로젝트의 Drift ORM 패턴. 테이블 목록, DAO 쿼리 작성법, 마이그레이션 패턴, customSelect, transaction 사용법.
user-invocable: false
---

# Drift Patterns

## DB 구조 (app_database.dart)
- 파일: `merchant_local/lib/core/database/app_database.dart`
- 현재 schemaVersion: **4** (v5 예정 — HLC + isDeleted)
- WAL 모드 + synchronous=NORMAL + cache_size 64MB 적용됨

### 테이블 목록
```
마스터:  Brands, Sources, Products, SizeCharts
핵심:    Items, Purchases, Sales, SaleAdjustments
부속:    StatusLogs, InspectionRejections, Repairs, Shipments,
         SupplierReturns, OrderCancellations, SampleUsages
설정:    PlatformFeeRules, PoizonSyncLogs, SyncMeta
POIZON:  PoizonSkuCache, PoizonListings, PoizonOrders
```

### DAO 목록
```dart
itemDaoProvider     → ItemDao      (items, products, status_logs)
purchaseDaoProvider → PurchaseDao
saleDaoProvider     → SaleDao
masterDaoProvider   → MasterDao    (brands, sources, products, size_charts)
subRecordDaoProvider → SubRecordDao (status_logs, repairs, shipments, ...)
skuDaoProvider      → SkuDao
listingDaoProvider  → ListingDao
orderDaoProvider    → OrderDao
```

## DAO 기본 패턴

```dart
@DriftAccessor(tables: [Items, Products, StatusLogs])
class ItemDao extends DatabaseAccessor<AppDatabase> with _$ItemDaoMixin {
  ItemDao(super.db);

  // 전체 조회 (Future)
  Future<List<ItemData>> getAll() =>
      (select(items)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  // 실시간 스트림
  Stream<List<ItemData>> watchAll() =>
      (select(items)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  // 단건 스트림 (상세 페이지용)
  Stream<ItemData?> watchById(String id) =>
      (select(items)..where((t) => t.id.equals(id))).watchSingleOrNull();

  // 조건 필터
  Stream<List<ItemData>> watchByStatuses(List<String> statuses) =>
      (select(items)
            ..where((t) => t.currentStatus.isIn(statuses))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();
}
```

## JOIN 쿼리

```dart
// items + products JOIN
final query = select(items).join([
  innerJoin(products, products.id.equalsExp(items.productId)),
]);
query.where(products.modelCode.equals(modelCode));
query.orderBy([OrderingTerm.asc(items.createdAt)]);
final rows = await query.get();
final itemList = rows.map((r) => r.readTable(items)).toList();
```

## customSelect (집계/복잡 쿼리)

```dart
// 상태별 카운트
final results = await customSelect(
  'SELECT current_status, COUNT(*) as cnt FROM items GROUP BY current_status',
  readsFrom: {items},
).get();
return {for (final r in results) r.read<String>('current_status'): r.read<int>('cnt')};

// 파라미터 바인딩
final results = await customSelect(
  'SELECT * FROM items WHERE current_status = ? LIMIT ?',
  variables: [Variable.withString(status), Variable.withInt(limit)],
  readsFrom: {items},
).get();
```

## transaction (상태 변경 패턴)

```dart
await transaction(() async {
  // 1. 현재 상태 조회
  final item = await getById(itemId);
  if (item == null) throw StateError('아이템 없음: $itemId');

  // 2. 전이 검증
  final allowed = validTransitions[item.currentStatus];
  if (allowed != null && !allowed.contains(newStatus)) {
    throw InvalidStatusTransitionException(itemId: itemId, from: item.currentStatus, to: newStatus);
  }

  final now = DateTime.now().toIso8601String();

  // 3. items 업데이트
  await (update(items)..where((t) => t.id.equals(itemId))).write(
    ItemsCompanion(currentStatus: Value(newStatus), updatedAt: Value(now)),
  );

  // 4. 로그 기록
  await into(statusLogs).insert(StatusLogsCompanion.insert(
    id: _uuid.v4(),
    itemId: itemId,
    oldStatus: Value(item.currentStatus),
    newStatus: newStatus,
    note: Value(note),
    changedAt: Value(now),
  ));
});
```

## INSERT / UPDATE / DELETE 패턴

```dart
// INSERT
await into(items).insert(ItemsCompanion.insert(id: _uuid.v4(), ...));
await into(items).insertOnConflictUpdate(companion); // upsert

// UPDATE (조건부)
await (update(items)..where((t) => t.id.equals(id))).write(
  ItemsCompanion(currentStatus: Value('LISTED'), updatedAt: Value(now)),
);

// DELETE
await (delete(items)..where((t) => t.id.equals(id))).go();
```

## 검색 패턴 (LIKE)

```dart
final pattern = '%$query%';
final result = select(items).join([
  innerJoin(products, products.id.equalsExp(items.productId)),
]);
result.where(
  items.sku.like(pattern) | products.modelCode.like(pattern) | products.modelName.like(pattern),
);
result.limit(50);
```

## 마이그레이션 패턴

```dart
@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) async {
    await m.createAll();
    await _seedPlatformFeeRules(); // 초기 데이터 삽입
  },
  onUpgrade: (m, from, to) async {
    // v4 → v5: 컬럼 추가 (안전한 방식)
    if (from < 5) {
      await m.addColumn(items, items.hlc);       // HLC 타임스탬프
      await m.addColumn(items, items.isDeleted); // soft delete
      // 인덱스 추가
      await m.createIndex(Index('idx_items_hlc', 'CREATE INDEX idx_items_hlc ON items(hlc)'));
    }
  },
);

// 컬럼 존재 여부 확인 (재실행 안전)
final cols = await customSelect("PRAGMA table_info('items')", readsFrom: {}).get();
final hasCol = cols.any((c) => c.read<String>('name') == 'hlc');
if (!hasCol) await m.addColumn(items, items.hlc);
```

## 성능 패턴
- N+1 방지: `getProductsByIds(List<String> ids)` 배치 조회
- 병렬 처리: `Future.wait([query1, query2, query3])`
- 인덱스: FK 컬럼(item_id, product_id, brand_id 등) 14개 인덱스 적용됨
- FIFO 재고: `orderBy([OrderingTerm.asc(items.createdAt)]).limit(1)` 패턴

## 코드 생성
```bash
cd merchant_local
dart run build_runner build --delete-conflicting-outputs
# 생성 파일: *.g.dart (gitignore됨)
```
