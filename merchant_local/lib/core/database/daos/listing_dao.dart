import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/listing_table.dart';

part 'listing_dao.g.dart';

@DriftAccessor(tables: [PoizonListings])
class ListingDao extends DatabaseAccessor<AppDatabase> with _$ListingDaoMixin {
  ListingDao(super.db);

  /// 전체 리스팅 (삭제되지 않은 것만)
  Future<List<PoizonListingData>> getAll() =>
      (select(poizonListings)..where((t) => t.isDeleted.equals(false))).get();

  /// 리스팅 스트림 (실시간 갱신)
  Stream<List<PoizonListingData>> watchAll() =>
      (select(poizonListings)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  /// 상태별 필터링
  Stream<List<PoizonListingData>> watchByStatus(String status) =>
      (select(poizonListings)
            ..where(
                (t) => t.status.equals(status) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  /// ID로 조회
  Future<PoizonListingData?> getById(String bidId) =>
      (select(poizonListings)..where((t) => t.bidId.equals(bidId)))
          .getSingleOrNull();

  /// Upsert
  Future<void> upsert(PoizonListingsCompanion entry) =>
      into(poizonListings).insertOnConflictUpdate(entry);

  /// 일괄 Upsert
  Future<void> upsertAll(List<PoizonListingsCompanion> entries) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(poizonListings, entry, onConflict: DoUpdate((_) => entry));
      }
    });
  }

  /// 소프트 삭제
  Future<void> softDelete(String bidId) =>
      (update(poizonListings)..where((t) => t.bidId.equals(bidId)))
          .write(const PoizonListingsCompanion(isDeleted: Value(true)));
}
