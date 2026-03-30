# 코드리뷰 — 2026-03-30

## 개요

- **대상**: `merchant_local/lib/` 전체
- **검토 파일 수**: 21개
- **발견 이슈**: 8건 (High 2 / Medium 3 / Low 3)
- **전체 평가**: B+ — 구조와 타입 안전성은 양호, 비동기 처리 패턴 개선 필요

---

## High

### H-1. 라우트 쿼리 파라미터 강제 언래핑
**파일**: `lib/app.dart:53`

```dart
// 현재 — productId가 URL에 없으면 런타임 크래시
productId: state.uri.queryParameters['productId']!,
```

`product_form_screen`으로 이동 시 `productId` 쿼리 파라미터가 누락되면 즉시 크래시. GoRouter는 쿼리 파라미터 누락을 컴파일 타임에 잡지 않는다.

**수정**: null 체크 후 리다이렉트 처리

```dart
final productId = state.uri.queryParameters['productId'];
if (productId == null) return const SizedBox.shrink(); // 또는 error route
return ProductFormScreen(itemId: state.pathParameters['id']!, productId: productId);
```

---

### H-2. SQL 날짜 필터 문자열 보간
**파일**: `lib/features/purchases/purchases_screen.dart:82,85`

```dart
// 현재 — 수동 이스케이프
where += " AND COALESCE(p.purchase_date, p.created_at) >= '${dateFrom.replaceAll("'", "''")}'";
```

값이 DatePicker 출처라 실제 injection 위험은 낮지만 Drift 권장 방식 위반. `Variable` 바인딩 사용 필요.

**수정**:

```dart
final vars = <Variable>[];
if (dateFrom != null) {
  where += " AND COALESCE(p.purchase_date, p.created_at) >= ?";
  vars.add(Variable.withString(dateFrom));
}
if (dateTo != null) {
  where += " AND COALESCE(p.purchase_date, p.created_at) <= ?";
  vars.add(Variable.withString(dateTo));
}
// customSelect( ..., variables: vars )
```

---

## Medium

### M-1. `build()` 내 unawaited async 호출
**파일**: `lib/features/inventory/sale_form_screen.dart:222`, `lib/features/inventory/purchase_form_screen.dart:134`

```dart
// 현재 — build()에서 fire-and-forget
Widget build(BuildContext context) {
  if (widget.isEditing && !_loaded) {
    _loadExisting(); // await 없음
  }
  ...
}
```

`_loaded` 플래그로 재진입은 방지되지만, `_loadExisting()` 내부에서 예외 발생 시 `_loaded = true` 상태에서 데이터 없이 UI가 stuck. `build()`는 프레임마다 호출될 수 있어 비동기 호출 위치로 부적절.

**수정**: `initState()`로 이전

```dart
@override
void initState() {
  super.initState();
  if (widget.isEditing) _loadExisting();
}
// build()에서 _loadExisting() 호출 제거
```

---

### M-2. 배치 작업 DB 트랜잭션 누락
**파일**: `lib/features/inventory/widgets/batch_actions.dart` (`_batchInspectionPass`, `_batchStatusChange` 등)

```dart
// 현재 — N개 아이템을 개별 await로 처리, 중간 실패 시 부분 업데이트 잔존
for (final item in items) {
  await ref.read(saleDaoProvider).updateSale(...);      // DB write 1
  await ref.read(itemDaoProvider).updateStatus(...);   // DB write 2
}
```

10개 아이템 처리 중 5번째에서 예외 발생 시 앞 4개는 이미 반영된 상태. 롤백 불가.

**수정**: DAO에 배치 트랜잭션 메서드 추가 또는 `transaction()` 래핑

```dart
final db = ref.read(databaseProvider);
await db.transaction(() async {
  for (final item in items) {
    await ref.read(saleDaoProvider).updateSale(...);
    await ref.read(itemDaoProvider).updateStatus(...);
  }
});
```

---

### M-3. `defectType` 강제 언래핑
**파일**: `lib/features/inventory/status_actions.dart:285`

```dart
// 현재
if (action.needsInspection) {
  return _showInspectionDialog(
    defectType: action.defectType!, // nullable String을 강제 언래핑
  );
}
```

현재 `statusActions` 맵에서 `needsInspection: true`인 경우 항상 `defectType`이 설정되어 있어 실제로 NPE가 발생하지 않는다. 하지만 향후 `statusActions`에 항목 추가 시 `defectType` 누락 버그를 컴파일 타임에 잡을 수 없음.

**수정**: null 체크로 방어

```dart
if (action.needsInspection) {
  final defectType = action.defectType;
  if (defectType == null) return false;
  return _showInspectionDialog(defectType: defectType, ...);
}
```

---

## Low

### L-1. N+1 Delete 루프
**파일**: `lib/core/database/daos/sub_record_dao.dart:190-192`

```dart
// 현재 — 건당 개별 delete
for (final id in idsToDelete) {
  await (delete(shipments)..where((t) => t.id.equals(id))).go();
}
```

`idsToDelete`가 많을수록 DB 왕복 횟수 선형 증가.

**수정**: 단일 쿼리로

```dart
if (idsToDelete.isNotEmpty) {
  await (delete(shipments)..where((t) => t.id.isIn(idsToDelete))).go();
}
return idsToDelete.length;
```

---

### L-2. `firstWhere` + force unwrap 패턴
**파일**: `lib/features/inventory/item_detail_screen.dart:29-30`

```dart
// 현재 — cast 후 강제 언래핑
return sources
    .cast<Source?>()
    .firstWhere((s) => s!.id == sourceId, orElse: () => null);
```

`collection` 패키지의 `firstWhereOrNull`이 더 명확하고 안전.

**수정**:

```dart
return sources.firstWhereOrNull((s) => s.id == sourceId);
```

---

### L-3. `_sourceProvider` 전체 목록 조회 후 클라이언트 필터
**파일**: `lib/features/inventory/item_detail_screen.dart:24-31`

```dart
// 현재 — 전체 sources 조회 후 메모리 필터
final sources = await ref.watch(masterDaoProvider).getAllSources();
return sources.firstWhereOrNull((s) => s.id == sourceId);
```

sources 수가 많아질 경우 불필요한 데이터 전송. `MasterDao`에 `getSourceById(id)` 메서드가 없는 상황.

**수정**: `MasterDao`에 단건 조회 메서드 추가

```dart
// master_dao.dart
Future<Source?> getSourceById(String id) =>
    (select(sources)..where((t) => t.id.equals(id))).getSingleOrNull();

// item_detail_screen.dart
final _sourceProvider = FutureProvider.family<Source?, String>((ref, sourceId) {
  return ref.watch(masterDaoProvider).getSourceById(sourceId);
});
```

---

## 수정 우선순위 요약

| # | 심각도 | 파일 | 요약 |
|---|--------|------|------|
| H-1 | **High** | app.dart:53 | 라우트 파라미터 강제 언래핑 → 크래시 |
| H-2 | **High** | purchases_screen.dart:82 | SQL 문자열 보간 |
| M-1 | Medium | sale_form_screen.dart:222, purchase_form_screen.dart:134 | build() 내 async 호출 |
| M-2 | Medium | batch_actions.dart | 배치 작업 트랜잭션 없음 |
| M-3 | Medium | status_actions.dart:285 | nullable 강제 언래핑 |
| L-1 | Low | sub_record_dao.dart:190 | N+1 delete |
| L-2 | Low | item_detail_screen.dart:29 | firstWhere 패턴 |
| L-3 | Low | item_detail_screen.dart:24 | 전체 조회 후 클라이언트 필터 |

---

## 코드 강점 (유지)

- Drift ORM 타입 안전성 잘 활용 (DAO 구조, Variable 바인딩)
- Riverpod StreamProvider + `watchById` 패턴으로 상태 자동 반영
- `mounted` 체크 대부분 적절히 수행
- CSV 인젝션 방어 (`_escapeCsv`)
- 상태 전이 검증 (`statusActions` 맵으로 허용된 전이만 UI 노출)
- WAL 모드 + pragma 설정으로 SQLite 성능 최적화
- Completer 패턴으로 BottomSheet 결과 안전하게 수신
