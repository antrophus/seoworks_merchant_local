import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/brand_table.dart';
import '../tables/source_table.dart';
import '../tables/product_table.dart';
import '../tables/size_chart_table.dart';
import '../tables/platform_fee_rule_table.dart';

part 'master_dao.g.dart';

/// 마스터 데이터 DAO (브랜드, 매입처, 상품, 사이즈차트, 수수료규칙)
@DriftAccessor(
    tables: [Brands, Sources, Products, SizeCharts, PlatformFeeRules])
class MasterDao extends DatabaseAccessor<AppDatabase> with _$MasterDaoMixin {
  MasterDao(super.db);

  // ── Brands ──
  Future<List<Brand>> getAllBrands() =>
      (select(brands)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Stream<List<Brand>> watchAllBrands() =>
      (select(brands)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<Brand?> getBrandById(String id) =>
      (select(brands)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertBrand(BrandsCompanion entry) =>
      into(brands).insertOnConflictUpdate(entry);

  Future<void> insertAllBrands(List<BrandsCompanion> entries) async {
    await batch((b) {
      b.insertAll(brands, entries, mode: InsertMode.insertOrIgnore);
    });
  }

  // ── Sources ──
  Future<List<Source>> getAllSources() =>
      (select(sources)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Stream<List<Source>> watchAllSources() =>
      (select(sources)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<void> upsertSource(SourcesCompanion entry) =>
      into(sources).insertOnConflictUpdate(entry);

  Future<void> insertAllSources(List<SourcesCompanion> entries) async {
    await batch((b) {
      b.insertAll(sources, entries, mode: InsertMode.insertOrIgnore);
    });
  }

  // ── Products ──
  Future<List<Product>> getAllProducts() =>
      (select(products)..orderBy([(t) => OrderingTerm.asc(t.modelCode)])).get();

  Stream<List<Product>> watchAllProducts() =>
      (select(products)..orderBy([(t) => OrderingTerm.asc(t.modelCode)]))
          .watch();

  Future<Product?> getProductById(String id) =>
      (select(products)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Product?> getProductByModelCode(String modelCode) =>
      (select(products)..where((t) => t.modelCode.equals(modelCode)))
          .getSingleOrNull();

  Future<List<Product>> searchProducts(String query) =>
      (select(products)
            ..where((t) =>
                t.modelCode.like('%$query%') | t.modelName.like('%$query%')))
          .get();

  Future<void> upsertProduct(ProductsCompanion entry) =>
      into(products).insertOnConflictUpdate(entry);

  Future<void> insertAllProducts(List<ProductsCompanion> entries) async {
    await batch((b) {
      b.insertAll(products, entries, mode: InsertMode.insertOrIgnore);
    });
  }

  /// 모든 소스를 Map으로 (id → Source)
  Future<Map<String, Source>> getAllSourcesMap() async {
    final list = await getAllSources();
    return {for (final s in list) s.id: s};
  }

  // ── Sources (filtered) ──
  Future<List<Source>> getSourcesByType(String type) =>
      (select(sources)
            ..where((t) => t.type.equals(type))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  // ── SizeCharts ──
  Future<List<SizeChartData>> getSizeChartsByBrand(String brandName) =>
      (select(sizeCharts)
            ..where((t) => t.brand.equals(brandName.toUpperCase()))
            ..orderBy([(t) => OrderingTerm.asc(t.kr)]))
          .get();

  Future<List<SizeChartData>> getSizeChartsByBrandAndTarget(
          String brandName, String target) =>
      (select(sizeCharts)
            ..where((t) =>
                t.brand.equals(brandName.toUpperCase()) &
                t.target.equals(target))
            ..orderBy([(t) => OrderingTerm.asc(t.kr)]))
          .get();

  /// 해당 브랜드의 사이즈차트에 존재하는 target 목록 (MEN, WOMEN, KIDS)
  Future<List<String>> getSizeChartTargets(String brandName) async {
    final results = await customSelect(
      'SELECT DISTINCT target FROM size_charts WHERE brand = ? ORDER BY target',
      variables: [Variable.withString(brandName.toUpperCase())],
      readsFrom: {sizeCharts},
    ).get();
    return results.map((r) => r.read<String>('target')).toList();
  }

  Future<void> insertAllSizeCharts(List<SizeChartsCompanion> entries) async {
    await batch((b) {
      b.insertAll(sizeCharts, entries, mode: InsertMode.insertOrIgnore);
    });
  }

  // ── PlatformFeeRules ──
  Future<List<PlatformFeeRuleData>> getAllFeeRules() =>
      select(platformFeeRules).get();

  Future<void> upsertFeeRule(PlatformFeeRulesCompanion entry) =>
      into(platformFeeRules).insertOnConflictUpdate(entry);

  Future<void> insertAllFeeRules(
      List<PlatformFeeRulesCompanion> entries) async {
    await batch((b) {
      b.insertAll(platformFeeRules, entries, mode: InsertMode.insertOrIgnore);
    });
  }
}
