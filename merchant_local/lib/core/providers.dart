import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/app_database.dart';
import 'services/hlc_clock_service.dart';
import 'services/google_drive_service.dart';
import 'services/sync_scheduler.dart';
import 'database/daos/sku_dao.dart';
import 'database/daos/listing_dao.dart';
import 'database/daos/order_dao.dart';
import 'database/daos/item_dao.dart';
import 'database/daos/purchase_dao.dart';
import 'database/daos/sale_dao.dart';
import 'database/daos/master_dao.dart';
import 'database/daos/sub_record_dao.dart';
import 'api/poizon_client.dart';
import 'services/sync_engine.dart';

/// 앱 전역 Database 인스턴스
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// HLC 시계 — main.dart에서 override 필수
final hlcClockProvider = Provider<HlcClockService>((ref) {
  throw UnimplementedError('hlcClockProvider must be overridden at startup');
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

/// Google Drive 서비스 — 싱글턴 (로그인 상태 유지)
final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  return GoogleDriveService();
});

/// Sync Engine — main.dart에서 hlcClockProvider override 필수
final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    db: ref.watch(databaseProvider),
    driveService: ref.watch(googleDriveServiceProvider),
    clock: ref.watch(hlcClockProvider),
  );
});

/// 자동 동기화 스케줄러 — main.dart에서 override 필수 (start/stop 제어)
final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  final engine = ref.watch(syncEngineProvider);
  final scheduler = SyncScheduler(engine);
  ref.onDispose(() => scheduler.stop());
  return scheduler; // main.dart override 없을 경우 폴백 (미시작 상태)
});

/// 마지막 동기화 시각
final lastSyncAtProvider = FutureProvider<DateTime?>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await (db.select(db.syncMeta)
        ..where((t) => t.key.equals('last_sync_at')))
      .getSingleOrNull();
  if (rows == null) return null;
  return DateTime.tryParse(rows.value);
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

final itemStatusCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final items = await ref.watch(itemsProvider.future);
  final counts = <String, int>{};
  for (final item in items) {
    counts[item.currentStatus] = (counts[item.currentStatus] ?? 0) + 1;
  }
  return counts;
});

/// 대시보드 자산 개요
final assetSummaryProvider = FutureProvider<Map<String, int>>((ref) {
  ref.watch(itemsProvider);
  return ref.read(itemDaoProvider).getAssetSummary();
});

/// 대시보드 브랜드 Top 6
final topBrandsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(itemsProvider);
  return ref.read(itemDaoProvider).getTopBrands(6);
});

/// 대시보드 긴급 알림 (검수 12일 경과)
final overdueInspectionCountProvider = FutureProvider<int>((ref) {
  ref.watch(itemsProvider);
  return ref.read(itemDaoProvider).getOverdueInspectionCount(12);
});

/// 대시보드 최근 활동 로그
final recentActivityProvider = FutureProvider<List<StatusLogData>>((ref) {
  ref.watch(itemsProvider);
  return ref.read(subRecordDaoProvider).getRecentStatusLogs();
});
