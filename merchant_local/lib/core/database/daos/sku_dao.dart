import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sku_table.dart';

part 'sku_dao.g.dart';

@DriftAccessor(tables: [PoizonSkuCache])
class SkuDao extends DatabaseAccessor<AppDatabase> with _$SkuDaoMixin {
  SkuDao(super.db);

  /// 전체 SKU 목록 (삭제되지 않은 것만)
  Future<List<PoizonSkuCacheData>> getAll() =>
      (select(poizonSkuCache)..where((t) => t.isDeleted.equals(false))).get();

  /// 전체 SKU 스트림
  Stream<List<PoizonSkuCacheData>> watchAll() =>
      (select(poizonSkuCache)..where((t) => t.isDeleted.equals(false))).watch();

  /// ID로 조회
  Future<PoizonSkuCacheData?> getById(String id) =>
      (select(poizonSkuCache)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  /// 품번 또는 상품명으로 검색
  Future<List<PoizonSkuCacheData>> search(String query) =>
      (select(poizonSkuCache)
            ..where((t) =>
                (t.articleNumber.like('%$query%') |
                    t.productName.like('%$query%') |
                    t.brandName.like('%$query%')) &
                t.isDeleted.equals(false)))
          .get();

  /// Upsert
  Future<void> upsert(PoizonSkuCacheCompanion entry) =>
      into(poizonSkuCache).insertOnConflictUpdate(entry);

  /// 일괄 Upsert
  Future<void> upsertAll(List<PoizonSkuCacheCompanion> entries) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(poizonSkuCache, entry, onConflict: DoUpdate((_) => entry));
      }
    });
  }

  /// 소프트 삭제
  Future<void> softDelete(String id) =>
      (update(poizonSkuCache)..where((t) => t.id.equals(id)))
          .write(const PoizonSkuCacheCompanion(isDeleted: Value(true)));
}
