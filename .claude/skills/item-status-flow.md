---
name: item-status-flow
description: ItemStatus 상태 전이 규칙, statusLabels, statusActions, InvalidStatusTransitionException. 상태 관련 코드 작성 시 이 스킬을 참조한다.
user-invocable: false
---

# Item Status Flow

## 파일 위치
- 전이 검증: `merchant_local/lib/core/database/daos/item_dao.dart` (validTransitions, updateStatus)
- UI 액션 정의: `merchant_local/lib/features/inventory/status_actions.dart`
- 라벨/필터: `merchant_local/lib/features/inventory/inventory_providers.dart`

## validTransitions (item_dao.dart)

```dart
const validTransitions = <String, Set<String>>{
  'ORDER_PLACED':     {'OFFICE_STOCK', 'ORDER_CANCELLED'},
  'OFFICE_STOCK':     {'LISTED', 'SUPPLIER_RETURN', 'SAMPLE', 'DISPOSED'},
  'LISTED':           {'OUTGOING', 'OFFICE_STOCK', 'POIZON_STORAGE'},
  'SOLD':             {'OUTGOING', 'LISTED'},
  'OUTGOING':         {'IN_INSPECTION'},
  'IN_INSPECTION':    {'SETTLED', 'DEFECT_FOR_SALE', 'DEFECT_HELD', 'RETURNING', 'POIZON_STORAGE', 'CANCEL_RETURNING'},
  'SETTLED':          {},   // 종단 상태 — 재전이 불가, SETTLED→SETTLED 에러 주의
  'DEFECT_FOR_SALE':  {'DEFECT_SOLD', 'REPAIRING'},
  'DEFECT_SOLD':      {'DEFECT_SETTLED'},
  'DEFECT_SETTLED':   {},   // 종단 상태
  'DEFECT_HELD':      {'OFFICE_STOCK', 'REPAIRING', 'SUPPLIER_RETURN', 'DISPOSED'},
  'POIZON_STORAGE':   {'SETTLED', 'CANCEL_RETURNING'},
  'CANCEL_RETURNING': {'OFFICE_STOCK'},
  'RETURNING':        {'OFFICE_STOCK', 'REPAIRING'},
  'REPAIRING':        {'OFFICE_STOCK', 'SUPPLIER_RETURN', 'DISPOSED', 'SAMPLE'},
  'SUPPLIER_RETURN':  {},   // 종단 상태
  'DISPOSED':         {},   // 종단 상태
  'SAMPLE':           {},   // 종단 상태
  'ORDER_CANCELLED':  {},   // 종단 상태
};
```

## statusLabels (inventory_providers.dart)

```dart
const statusLabels = <String, String>{
  'ORDER_PLACED': '주문완료',      'ORDER_CANCELLED': '주문취소',
  'OFFICE_STOCK': '사무실재고',    'OUTGOING': '발송중',
  'IN_INSPECTION': '검수중',       'LISTED': '리스팅',
  'SOLD': '판매완료',              'SETTLED': '정산완료',
  'RETURNING': '반송중',           'DEFECT_FOR_SALE': '불량판매',
  'DEFECT_SOLD': '불량판매완료',   'DEFECT_SETTLED': '불량정산',
  'POIZON_STORAGE': '포이즌보관',  'CANCEL_RETURNING': '취소반송',
  'SUPPLIER_RETURN': '공급처반품', 'DISPOSED': '폐기',
  'SAMPLE': '샘플',               'DEFECT_HELD': '불량보류',
  'REPAIRING': '수선중',
};
```

## mainFilters / moreFilters (inventory_providers.dart)

```dart
const mainFilters = [
  FilterDef('판매중',   ['LISTED', 'POIZON_STORAGE'],       subLabels: ['리스팅', '포이즌보관']),
  FilterDef('발송·검수', ['OUTGOING', 'IN_INSPECTION'],     subLabels: ['발송중', '검수중']),
  FilterDef('미등록',   ['ORDER_PLACED', 'OFFICE_STOCK'],   subLabels: ['입고대기', '미등록재고']),
  FilterDef('정산완료', ['SETTLED', 'DEFECT_SETTLED']),
];
const moreFilters = [
  FilterDef('판매완료', ['SOLD']),
  FilterDef('불량보류', ['DEFECT_HELD']),
  FilterDef('수선중',   ['REPAIRING']),
  FilterDef('반송중',   ['RETURNING', 'CANCEL_RETURNING'],  subLabels: ['하자반송', '취소반송']),
  FilterDef('기타',     ['ORDER_CANCELLED', 'SUPPLIER_RETURN', 'DISPOSED', 'SAMPLE']),
];
```

## 상태 변경 API

```dart
// item_dao.dart — updateStatus (트랜잭션 + 로그 자동 기록)
await itemDao.updateStatus(itemId, 'OFFICE_STOCK', note: '입고 확인');
// 허용되지 않는 전이 → InvalidStatusTransitionException 발생
```

## StatusAction 구조 (status_actions.dart)

```dart
class StatusAction {
  final String label, targetStatus;
  final IconData icon;
  final Color color;
  // 추가 입력 필요 여부 플래그:
  final bool needsShipment, needsInspection, needsRepair, needsRepairComplete;
  final bool needsCancel, needsReturn, needsListing, needsSellAndShip;
  final String? defectType, repairOutcome;
}
```

## 종단 상태 (전이 불가)
`SETTLED`, `DEFECT_SETTLED`, `SUPPLIER_RETURN`, `DISPOSED`, `SAMPLE`, `ORDER_CANCELLED`

## 주의사항
- SETTLED → SETTLED 재호출 금지 (과거 버그). `showStatusActionSheet` 반환값을 Completer로 처리.
- 종단 상태 아이템에는 롱프레스 선택 UI 비활성화.
- 상태 변경 후 상세 페이지 갱신: `_itemProvider`를 StreamProvider + `watchById`로 구현.
