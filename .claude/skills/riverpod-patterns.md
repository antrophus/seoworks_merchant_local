---
name: riverpod-patterns
description: 이 프로젝트의 Riverpod Provider 패턴. 전역 Provider 목록, StreamProvider/FutureProvider/StateNotifierProvider 사용법, ref.watch vs ref.read 규칙.
user-invocable: false
---

# Riverpod Patterns

## 전역 Provider 목록 (core/providers.dart)

```dart
// DB 인스턴스 (싱글톤)
databaseProvider        Provider<AppDatabase>

// DAO Providers
itemDaoProvider         Provider<ItemDao>
purchaseDaoProvider     Provider<PurchaseDao>
saleDaoProvider         Provider<SaleDao>
masterDaoProvider       Provider<MasterDao>
subRecordDaoProvider    Provider<SubRecordDao>
skuDaoProvider          Provider<SkuDao>
listingDaoProvider      Provider<ListingDao>
orderDaoProvider        Provider<OrderDao>

// 실시간 스트림 (UI rebuild 트리거)
itemsProvider           StreamProvider<List<ItemData>>       // 재고 전체
poizonListingsProvider  StreamProvider<List<PoizonListingData>>
poizonOrdersProvider    StreamProvider<List<PoizonOrderData>>

// 대시보드 FutureProviders (itemsProvider 의존)
assetSummaryProvider           FutureProvider<Map<String, int>>
topBrandsProvider              FutureProvider<List<Map<String, dynamic>>>
overdueInspectionCountProvider FutureProvider<int>
recentActivityProvider         FutureProvider<List<StatusLogData>>
itemStatusCountsProvider       FutureProvider<Map<String, int>>

// 검색/필터 상태
skuSearchQueryProvider  StateProvider<String>
skuSearchResultProvider FutureProvider<List<PoizonSkuCacheData>>
```

## 인벤토리 전용 Providers (features/inventory/inventory_providers.dart)

```dart
inventoryFilterProvider         StateProvider<String?>     // 현재 필터 탭
inventorySearchProvider         StateProvider<String>      // 검색어
inventorySortByProvider         StateProvider<String>      // 'created'|'purchasePrice'|'listedPrice'|'sellPrice'
inventorySortAscProvider        StateProvider<bool>
inventoryPersonalFilterProvider StateProvider<bool?>       // null=전체, true=개인, false=사업용

selectionProvider               StateNotifierProvider<SelectionNotifier, Set<String>>
```

## Provider 작성 패턴

### DAO를 쓰는 FutureProvider (대시보드 통계)
```dart
// ref.watch(itemsProvider) 의존성 필수 — items 변경 시 자동 갱신
final myStatsProvider = FutureProvider<Map<String, int>>((ref) {
  ref.watch(itemsProvider);                    // 의존성 구독
  return ref.read(itemDaoProvider).getStats(); // read로 DAO 접근
});
```

### 아이템 단건 실시간 감지 (상세 페이지)
```dart
// StreamProvider로 watchById 연결 — 상태 변경 후 자동 갱신
final _itemProvider = StreamProvider.autoDispose.family<ItemData?, String>(
  (ref, id) => ref.watch(itemDaoProvider).watchById(id),
);
// 사용: ref.watch(_itemProvider(item.id))
```

### SelectionNotifier 사용
```dart
final notifier = ref.read(selectionProvider.notifier);
notifier.toggle(itemId);
notifier.clear();
notifier.addAll(ids);
notifier.selectAll(ids);      // 이미 전체 선택이면 해제
final selected = ref.watch(selectionProvider); // Set<String>
final isActive = selected.isNotEmpty;
```

## ref.watch vs ref.read 규칙
| 상황 | 사용 |
|------|------|
| build/Provider 본문에서 의존성 구독 | `ref.watch` |
| 이벤트 핸들러(onPressed 등) 내 1회 접근 | `ref.read` |
| StreamProvider/FutureProvider 데이터 접근 | `ref.watch(provider)` |
| Provider 내부에서 다른 DAO 접근 | `ref.read(daoProvider)` |

## 주의사항
- 대시보드 FutureProvider는 반드시 `ref.watch(itemsProvider)` 의존성 추가. 없으면 items 변경 시 갱신 안 됨.
- `autoDispose` + `family`는 상세 페이지처럼 특정 ID를 구독할 때 사용.
- StateProvider 값 변경: `ref.read(provider.notifier).state = newValue`
