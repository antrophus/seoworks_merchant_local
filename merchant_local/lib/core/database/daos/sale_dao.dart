import 'dart:math';
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sale_table.dart';
import '../tables/sale_adjustment_table.dart';
import '../tables/item_table.dart';
import '../tables/product_table.dart';
import '../tables/platform_fee_rule_table.dart';

part 'sale_dao.g.dart';

@DriftAccessor(
    tables: [Sales, SaleAdjustments, Items, Products, PlatformFeeRules])
class SaleDao extends DatabaseAccessor<AppDatabase> with _$SaleDaoMixin {
  SaleDao(super.db);

  /// item_id로 판매 조회
  Future<SaleData?> getByItemId(String itemId) =>
      (select(sales)..where((t) => t.itemId.equals(itemId)))
          .getSingleOrNull();

  /// 플랫폼별 판매 목록
  Stream<List<SaleData>> watchByPlatform(String platform) =>
      (select(sales)
            ..where((t) => t.platform.equals(platform))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  /// 판매 등록 (수수료 + 정산금 자동 계산)
  Future<void> insertSale(SalesCompanion entry) async {
    final computed = await _computeSettlement(entry);
    await into(sales).insert(computed);
  }

  /// 판매 수정 (수수료 + 정산금 재계산)
  Future<void> updateSale(String id, SalesCompanion entry) async {
    final computed = await _computeSettlement(entry);
    await (update(sales)..where((t) => t.id.equals(id))).write(computed);
  }

  /// 정산금 계산 로직 (calculate_sale_settlement 트리거 이식)
  Future<SalesCompanion> _computeSettlement(SalesCompanion entry) async {
    final sellPrice = entry.sellPrice.present ? entry.sellPrice.value : null;
    if (sellPrice == null) return entry;

    final platform = entry.platform.present ? entry.platform.value : '';
    final adjustmentTotal =
        entry.adjustmentTotal.present ? entry.adjustmentTotal.value : 0;

    int? fee;
    double? feeRate;

    if (platform == 'POIZON') {
      // 카테고리별 수수료 규칙 조회
      String? category;
      if (entry.itemId.present) {
        final item = await (select(items)
              ..where((t) => t.id.equals(entry.itemId.value)))
            .getSingleOrNull();
        if (item != null) {
          final product = await (select(products)
                ..where((t) => t.id.equals(item.productId)))
              .getSingleOrNull();
          category = product?.category;
        }
      }

      // platform_fee_rules에서 매칭
      var rule = await (select(platformFeeRules)
            ..where((t) =>
                t.platform.equals('POIZON') &
                t.category.equals(category ?? 'default')))
          .getSingleOrNull();

      // 폴백: default 카테고리
      rule ??= await (select(platformFeeRules)
            ..where((t) =>
                t.platform.equals('POIZON') & t.category.equals('default')))
          .getSingleOrNull();

      // 하드코딩 폴백
      final rate = rule?.feeRate ?? 0.10;
      final minFee = rule?.minFee ?? 15000;
      final maxFee = rule?.maxFee ?? 45000;

      final rawFee = (sellPrice * rate).round();
      fee = max(minFee, min(rawFee, maxFee));
      feeRate = fee / sellPrice;
    } else if (platform == 'DIRECT' || platform == 'OTHER') {
      fee = 0;
      feeRate = 0;
    } else {
      // KREAM, SOLDOUT 등 — platform_fee_rate 직접 지정
      feeRate =
          entry.platformFeeRate.present ? entry.platformFeeRate.value : null;
      if (feeRate != null) {
        fee = (sellPrice * feeRate).round();
      }
    }

    final settlement =
        fee != null ? sellPrice - fee + adjustmentTotal : null;

    return entry.copyWith(
      platformFee: Value(fee),
      platformFeeRate: Value(feeRate),
      settlementAmount: Value(settlement),
    );
  }

  /// 조정금 합계 동기화 + 정산금 재계산
  Future<void> syncAdjustmentTotal(String saleId) async {
    // SUM(amount)
    final totalQuery = customSelect(
      'SELECT COALESCE(SUM(amount), 0) as total FROM sale_adjustments WHERE sale_id = ?',
      variables: [Variable.withString(saleId)],
      readsFrom: {saleAdjustments},
    );
    final result = await totalQuery.getSingle();
    final total = result.read<int>('total');

    // sales 업데이트
    final sale = await (select(sales)..where((t) => t.id.equals(saleId)))
        .getSingleOrNull();
    if (sale == null) return;

    await updateSale(
      saleId,
      SalesCompanion(
        itemId: Value(sale.itemId),
        platform: Value(sale.platform),
        sellPrice: Value(sale.sellPrice),
        adjustmentTotal: Value(total),
        platformFeeRate: Value(sale.platformFeeRate),
      ),
    );
  }

  /// 조정금 추가
  Future<void> addAdjustment(SaleAdjustmentsCompanion entry) async {
    await into(saleAdjustments).insert(entry);
    if (entry.saleId.present) {
      await syncAdjustmentTotal(entry.saleId.value);
    }
  }

  /// 조정금 삭제
  Future<void> deleteAdjustment(String adjustmentId, String saleId) async {
    await (delete(saleAdjustments)..where((t) => t.id.equals(adjustmentId)))
        .go();
    await syncAdjustmentTotal(saleId);
  }

  /// 조정금 목록
  Future<List<SaleAdjustmentData>> getAdjustments(String saleId) =>
      (select(saleAdjustments)..where((t) => t.saleId.equals(saleId))).get();

  /// 일괄 Insert (데이터 임포트용)
  Future<void> insertAll(List<SalesCompanion> entries) async {
    await batch((b) {
      b.insertAll(sales, entries, mode: InsertMode.insertOrIgnore);
    });
  }

  Future<void> insertAllAdjustments(
      List<SaleAdjustmentsCompanion> entries) async {
    await batch((b) {
      b.insertAll(saleAdjustments, entries, mode: InsertMode.insertOrIgnore);
    });
  }
}
