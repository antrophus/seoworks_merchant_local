import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/app_database.dart';
import 'database/daos/sku_dao.dart';
import 'database/daos/listing_dao.dart';
import 'database/daos/order_dao.dart';
import 'database/daos/item_dao.dart';
import 'database/daos/purchase_dao.dart';
import 'database/daos/sale_dao.dart';
import 'database/daos/master_dao.dart';
import 'database/daos/sub_record_dao.dart';
import 'api/poizon_client.dart';

/// 앱 전역 Database 인스턴스
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// ── POIZON API 캐시 DAOs ──
final skuDaoProvider = Provider<SkuDao>((ref) {
  return ref.watch(databaseProvider).skuDao;
});

final listingDaoProvider = Provider<ListingDao>((ref) {
  return ref.watch(databaseProvider).listingDao;
});

final orderDaoProvider = Provider<OrderDao>((ref) {
  return ref.watch(databaseProvider).orderDao;
});

/// ── 핵심 비즈니스 DAOs ──
final itemDaoProvider = Provider<ItemDao>((ref) {
  return ref.watch(databaseProvider).itemDao;
});

final purchaseDaoProvider = Provider<PurchaseDao>((ref) {
  return ref.watch(databaseProvider).purchaseDao;
});

final saleDaoProvider = Provider<SaleDao>((ref) {
  return ref.watch(databaseProvider).saleDao;
});

final masterDaoProvider = Provider<MasterDao>((ref) {
  return ref.watch(databaseProvider).masterDao;
});

final subRecordDaoProvider = Provider<SubRecordDao>((ref) {
  return ref.watch(databaseProvider).subRecordDao;
});

/// POIZON Client 설정 상태
final poizonConfiguredProvider = FutureProvider<bool>((ref) async {
  return PoizonClient().restore();
});

/// SKU 검색 결과 (POIZON 캐시)
final skuSearchQueryProvider = StateProvider<String>((ref) => '');

final skuSearchResultProvider =
    FutureProvider<List<PoizonSkuCacheData>>((ref) async {
  final query = ref.watch(skuSearchQueryProvider);
  if (query.isEmpty) return [];
  final dao = ref.watch(skuDaoProvider);
  return dao.search(query);
});

/// 포이즌 리스팅 목록 (실시간)
final poizonListingsProvider = StreamProvider<List<PoizonListingData>>((ref) {
  return ref.watch(listingDaoProvider).watchAll();
});

/// 포이즌 주문 목록 (실시간)
final poizonOrdersProvider = StreamProvider<List<PoizonOrderData>>((ref) {
  return ref.watch(orderDaoProvider).watchAll();
});

/// ── 재고 관리 Providers ──
final itemsProvider = StreamProvider<List<ItemData>>((ref) {
  return ref.watch(itemDaoProvider).watchAll();
});

final itemStatusCountsProvider = FutureProvider<Map<String, int>>((ref) {
  return ref.watch(itemDaoProvider).getStatusCounts();
});
