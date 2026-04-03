import 'dart:math';
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sale_table.dart';
import '../tables/sale_adjustment_table.dart';
import '../tables/item_table.dart';
import '../tables/product_table.dart';
import '../tables/platform_fee_rule_table.dart';

part 'sale_dao.g.dart';

/// 판매 + 아이템 + 상품 조인 결과
class SaleWithItem {
  final SaleData sale;
  final ItemData item;
  final Product product;

  const SaleWithItem({
    required this.sale,
    required this.item,
    required this.product,
  });
}

@DriftAccessor(
    tables: [Sales, SaleAdjustments, Items, Products, PlatformFeeRules])
class SaleDao extends DatabaseAccessor<AppDatabase> with _$SaleDaoMixin {
  SaleDao(super.db);

  /// item_id로 판매 조회
  Future<SaleData?> getByItemId(String itemId) =>
      (select(sales)
            ..where((t) =>
                t.itemId.equals(itemId) & t.isDeleted.equals(false)))
          .getSingleOrNull();

  /// 플랫폼별 판매 목록
  Stream<List<SaleData>> watchByPlatform(String platform) =>
      (select(sales)
            ..where((t) =>
                t.platform.equals(platform) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  /// 판매 등록 (수수료 + 정산금 자동 계산)
  Future<void> insertSale(SalesCompanion entry) async {
    final computed = await _computeSettlement(entry);
    await into(sales).insert(
      computed.copyWith(hlc: Value(db.hlcClock?.increment().toString() ?? '')),
    );
  }

  /// 판매 수정 (수수료 + 정산금 재계산)
  Future<void> updateSale(String id, SalesCompanion entry) async {
    final computed = await _computeSettlement(entry);
    await (update(sales)..where((t) => t.id.equals(id))).write(
      computed.copyWith(hlc: Value(db.hlcClock?.increment().toString() ?? '')),
    );
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
    // SUM(amount) — 삭제되지 않은 조정금만
    final totalQuery = customSelect(
      'SELECT COALESCE(SUM(amount), 0) as total FROM sale_adjustments WHERE sale_id = ? AND is_deleted = 0',
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
    await into(saleAdjustments).insert(
      entry.copyWith(hlc: Value(db.hlcClock?.increment().toString() ?? '')),
    );
    if (entry.saleId.present) {
      await syncAdjustmentTotal(entry.saleId.value);
    }
  }

  /// 조정금 소프트 삭제
  Future<void> deleteAdjustment(String adjustmentId, String saleId) async {
    await (update(saleAdjustments)
          ..where((t) => t.id.equals(adjustmentId)))
        .write(SaleAdjustmentsCompanion(
      isDeleted: const Value(true),
      hlc: Value(db.hlcClock?.increment().toString() ?? ''),
    ));
    await syncAdjustmentTotal(saleId);
  }

  /// 조정금 목록
  Future<List<SaleAdjustmentData>> getAdjustments(String saleId) =>
      (select(saleAdjustments)
            ..where((t) =>
                t.saleId.equals(saleId) & t.isDeleted.equals(false)))
          .get();

  /// 판매 내역 목록 (아이템+상품 JOIN, 필터 지원)
  Future<List<SaleWithItem>> getSalesWithItems({
    String? platform,
    String? dateFrom,
    String? dateTo,
  }) async {
    final query = select(sales).join([
      innerJoin(items, items.id.equalsExp(sales.itemId)),
      innerJoin(products, products.id.equalsExp(items.productId)),
    ]);

    // 정산 관련 상태만
    query.where(items.currentStatus.isIn([
      'SOLD',
      'SETTLED',
      'DEFECT_SOLD',
      'DEFECT_SETTLED',
      'DEFECT_FOR_SALE',
      'DEFECT_HELD',
      'OUTGOING',
      'IN_INSPECTION',
      'LISTED',
      'POIZON_STORAGE',
    ]));

    query.where(sales.isDeleted.equals(false));
    query.where(items.isDeleted.equals(false));

    if (platform != null) {
      query.where(sales.platform.equals(platform));
    }
    if (dateFrom != null) {
      query.where(sales.saleDate.isBiggerOrEqualValue(dateFrom) |
          sales.createdAt.isBiggerOrEqualValue(dateFrom));
    }
    if (dateTo != null) {
      query.where(sales.saleDate.isSmallerOrEqualValue(dateTo) |
          sales.createdAt.isSmallerOrEqualValue(dateTo));
    }
    query.orderBy([OrderingTerm.desc(sales.createdAt)]);

    final rows = await query.get();
    return rows.map((row) => SaleWithItem(
          sale: row.readTable(sales),
          item: row.readTable(items),
          product: row.readTable(products),
        )).toList();
  }

  /// 판매 통계 요약 (총 판매/정산/이익/마진율)
  Future<Map<String, num>> getSalesSummary({
    String? platform,
    String? dateFrom,
    String? dateTo,
  }) async {
    var where = "WHERE i.current_status IN ('SOLD','SETTLED','DEFECT_SOLD','DEFECT_SETTLED') AND s.is_deleted = 0 AND i.is_deleted = 0";
    final vars = <Variable>[];
    if (platform != null) {
      where += ' AND s.platform = ?';
      vars.add(Variable.withString(platform));
    }
    if (dateFrom != null) {
      where += ' AND COALESCE(s.settled_at, s.sale_date) >= ?';
      vars.add(Variable.withString(dateFrom));
    }
    if (dateTo != null) {
      where += ' AND COALESCE(s.settled_at, s.sale_date) <= ?';
      vars.add(Variable.withString(dateTo));
    }

    final result = await customSelect(
      '''
      SELECT
        COUNT(*) AS cnt,
        COALESCE(SUM(s.sell_price), 0) AS total_sell,
        COALESCE(SUM(s.settlement_amount), 0) AS total_settlement,
        COALESCE(SUM(s.settlement_amount - COALESCE(p.purchase_price, 0)), 0) AS total_profit,
        COALESCE(SUM(p.purchase_price), 0) AS total_cost
      FROM sales s
      JOIN items i ON i.id = s.item_id
      LEFT JOIN purchases p ON p.item_id = s.item_id
      $where
      ''',
      variables: vars,
      readsFrom: {sales, items},
    ).getSingle();

    final totalSell = result.read<int>('total_sell');
    final totalCost = result.read<int>('total_cost');
    return {
      'count': result.read<int>('cnt'),
      'totalSell': totalSell,
      'totalSettlement': result.read<int>('total_settlement'),
      'totalProfit': result.read<int>('total_profit'),
      'marginRate': totalCost > 0
          ? (result.read<int>('total_profit') / totalCost * 100)
          : 0.0,
    };
  }

  /// 월별 트렌드 (판매액/정산액/이익)
  Future<List<Map<String, dynamic>>> getMonthlyTrend({
    String? dateFrom,
    String? dateTo,
  }) async {
    var where = '';
    final vars = <Variable>[];
    if (dateFrom != null) {
      where += " AND COALESCE(s.settled_at, s.sale_date) >= ?";
      vars.add(Variable.withString(dateFrom));
    }
    if (dateTo != null) {
      where += " AND COALESCE(s.settled_at, s.sale_date) <= ?";
      vars.add(Variable.withString(dateTo));
    }

    final results = await customSelect(
      '''
      SELECT
        SUBSTR(COALESCE(s.settled_at, s.sale_date), 1, 7) AS month,
        COALESCE(SUM(s.sell_price), 0) AS sell,
        COALESCE(SUM(s.settlement_amount), 0) AS settlement,
        COALESCE(SUM(s.settlement_amount - COALESCE(p.purchase_price, 0)), 0) AS profit,
        CAST(COALESCE(SUM(CAST(p.purchase_price AS REAL) / 11.0), 0) AS INTEGER) AS vat_refund
      FROM sales s
      JOIN items i ON i.id = s.item_id
      LEFT JOIN purchases p ON p.item_id = s.item_id
      WHERE i.current_status IN ('SOLD','SETTLED','DEFECT_SOLD','DEFECT_SETTLED')
        AND COALESCE(s.settled_at, s.sale_date) IS NOT NULL
        AND s.is_deleted = 0
        AND i.is_deleted = 0
      $where
      GROUP BY month ORDER BY month
      ''',
      variables: vars,
      readsFrom: {sales, items},
    ).get();

    return results.map((r) => {
          'month': r.read<String>('month'),
          'sell': r.read<int>('sell'),
          'settlement': r.read<int>('settlement'),
          'profit': r.read<int>('profit'),
          'vatRefund': r.read<int>('vat_refund'),
        }).toList();
  }

  /// 플랫폼별 판매 분포
  Future<List<Map<String, dynamic>>> getPlatformDistribution({
    String? dateFrom,
    String? dateTo,
  }) async {
    var where = '';
    final vars = <Variable>[];
    if (dateFrom != null) {
      where += " AND COALESCE(s.settled_at, s.sale_date) >= ?";
      vars.add(Variable.withString(dateFrom));
    }
    if (dateTo != null) {
      where += " AND COALESCE(s.settled_at, s.sale_date) <= ?";
      vars.add(Variable.withString(dateTo));
    }
    final results = await customSelect(
      '''
      SELECT s.platform, COUNT(*) AS cnt,
             COALESCE(SUM(s.sell_price), 0) AS total_sell
      FROM sales s
      JOIN items i ON i.id = s.item_id
      WHERE i.current_status IN ('SOLD','SETTLED','DEFECT_SOLD','DEFECT_SETTLED')
        AND s.is_deleted = 0
        AND i.is_deleted = 0
      $where
      GROUP BY s.platform ORDER BY total_sell DESC
      ''',
      variables: vars,
      readsFrom: {sales, items},
    ).get();

    return results.map((r) => {
          'platform': r.read<String>('platform'),
          'count': r.read<int>('cnt'),
          'totalSell': r.read<int>('total_sell'),
        }).toList();
  }

  /// Top N 수익/손실 모델
  Future<List<Map<String, dynamic>>> getTopModels({
    required int limit,
    required bool ascending,
    String? dateFrom,
    String? dateTo,
  }) async {
    final order = ascending ? 'ASC' : 'DESC';
    var where = '';
    final vars = <Variable>[];
    if (dateFrom != null) {
      where += " AND COALESCE(s.settled_at, s.sale_date) >= ?";
      vars.add(Variable.withString(dateFrom));
    }
    if (dateTo != null) {
      where += " AND COALESCE(s.settled_at, s.sale_date) <= ?";
      vars.add(Variable.withString(dateTo));
    }
    vars.add(Variable.withInt(limit));

    final results = await customSelect(
      '''
      SELECT pr.model_code, pr.model_name,
             COUNT(*) AS cnt,
             COALESCE(SUM(s.settlement_amount - COALESCE(p.purchase_price, 0)), 0) AS profit
      FROM sales s
      JOIN items i ON i.id = s.item_id
      JOIN products pr ON pr.id = i.product_id
      LEFT JOIN purchases p ON p.item_id = s.item_id
      WHERE i.current_status IN ('SOLD','SETTLED','DEFECT_SOLD','DEFECT_SETTLED')
        AND s.settlement_amount IS NOT NULL
        AND p.purchase_price IS NOT NULL AND p.purchase_price > 0
        AND s.is_deleted = 0
        AND i.is_deleted = 0
      $where
      GROUP BY pr.model_code, pr.model_name
      ORDER BY profit $order
      LIMIT ?
      ''',
      variables: vars,
      readsFrom: {sales, items},
    ).get();

    return results.map((r) => {
          'modelCode': r.read<String>('model_code'),
          'modelName': r.read<String>('model_name'),
          'count': r.read<int>('cnt'),
          'profit': r.read<int>('profit'),
        }).toList();
  }

  /// 정산완료 판매 목록 — 정산일 기준 오래된순, 브랜드-모델명 포함
  Future<List<SaleWithItem>> getSettledSales({
    String? platform,
    String? dateFrom,
    String? dateTo,
  }) async {
    final query = select(sales).join([
      innerJoin(items, items.id.equalsExp(sales.itemId)),
      innerJoin(products, products.id.equalsExp(items.productId)),
    ]);

    query.where(items.currentStatus.isIn([
      'SETTLED',
      'DEFECT_SETTLED',
    ]));

    query.where(sales.isDeleted.equals(false));
    query.where(items.isDeleted.equals(false));

    if (platform != null) {
      query.where(sales.platform.equals(platform));
    }
    if (dateFrom != null) {
      query.where(sales.settledAt.isBiggerOrEqualValue(dateFrom) |
          sales.saleDate.isBiggerOrEqualValue(dateFrom));
    }
    if (dateTo != null) {
      query.where(sales.settledAt.isSmallerOrEqualValue(dateTo) |
          sales.saleDate.isSmallerOrEqualValue(dateTo));
    }
    // 정산일 기준 오래된순
    query.orderBy([OrderingTerm.asc(sales.settledAt)]);

    final rows = await query.get();
    return rows
        .map((row) => SaleWithItem(
              sale: row.readTable(sales),
              item: row.readTable(items),
              product: row.readTable(products),
            ))
        .toList();
  }

  /// 여러 아이템의 판매 데이터 배치 조회
  Future<Map<String, SaleData>> getByItemIds(List<String> itemIds) async {
    if (itemIds.isEmpty) return {};
    final results = await (select(sales)
          ..where((t) =>
              t.itemId.isIn(itemIds) & t.isDeleted.equals(false)))
        .get();
    return {for (final s in results) s.itemId: s};
  }

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

  /// 브랜드별 수익 Top N
  Future<List<Map<String, dynamic>>> getBrandProfit({
    int limit = 6,
    String? dateFrom,
    String? dateTo,
  }) async {
    var where = '';
    final vars = <Variable>[];
    if (dateFrom != null) {
      where += " AND COALESCE(s.settled_at, s.sale_date) >= ?";
      vars.add(Variable.withString(dateFrom));
    }
    if (dateTo != null) {
      where += " AND COALESCE(s.settled_at, s.sale_date) <= ?";
      vars.add(Variable.withString(dateTo));
    }
    vars.add(Variable.withInt(limit));

    final results = await customSelect(
      '''
      SELECT
        COALESCE(b.name, '기타') AS brand_name,
        COUNT(*) AS cnt,
        COALESCE(SUM(s.sell_price), 0) AS sell_total,
        COALESCE(SUM(s.settlement_amount - COALESCE(p.purchase_price, 0)), 0) AS profit
      FROM sales s
      JOIN items i ON i.id = s.item_id
      JOIN products pr ON pr.id = i.product_id
      LEFT JOIN brands b ON b.id = pr.brand_id
      LEFT JOIN purchases p ON p.item_id = s.item_id
      WHERE i.current_status IN ('SOLD','SETTLED','DEFECT_SOLD','DEFECT_SETTLED')
        AND s.settlement_amount IS NOT NULL
        AND s.is_deleted = 0
        AND i.is_deleted = 0
      $where
      GROUP BY brand_name
      ORDER BY profit DESC
      LIMIT ?
      ''',
      variables: vars,
      readsFrom: {sales, items, products},
    ).get();

    return results.map((r) => {
          'brandName': r.read<String>('brand_name'),
          'count': r.read<int>('cnt'),
          'sellTotal': r.read<int>('sell_total'),
          'profit': r.read<int>('profit'),
        }).toList();
  }

  /// 특정 모델의 건별 판매 기록
  Future<List<Map<String, dynamic>>> getSalesByModelCode(
    String modelCode, {
    String? dateFrom,
    String? dateTo,
    int limit = 30,
  }) async {
    var where = '';
    final vars = <Variable>[Variable.withString(modelCode)];
    if (dateFrom != null) {
      where += " AND COALESCE(s.settled_at, s.sale_date) >= ?";
      vars.add(Variable.withString(dateFrom));
    }
    if (dateTo != null) {
      where += " AND COALESCE(s.settled_at, s.sale_date) <= ?";
      vars.add(Variable.withString(dateTo));
    }
    vars.add(Variable.withInt(limit));

    final results = await customSelect(
      '''
      SELECT
        COALESCE(s.settled_at, s.sale_date) AS date,
        i.size_kr,
        s.platform,
        s.sell_price,
        s.settlement_amount,
        COALESCE(p.purchase_price, 0) AS purchase_price,
        (s.settlement_amount - COALESCE(p.purchase_price, 0)) AS profit
      FROM sales s
      JOIN items i ON i.id = s.item_id
      JOIN products pr ON pr.id = i.product_id
      LEFT JOIN purchases p ON p.item_id = s.item_id
      WHERE pr.model_code = ?
        AND i.current_status IN ('SOLD','SETTLED','DEFECT_SOLD','DEFECT_SETTLED')
        AND s.settlement_amount IS NOT NULL
        AND s.is_deleted = 0
        AND i.is_deleted = 0
      $where
      ORDER BY date DESC
      LIMIT ?
      ''',
      variables: vars,
      readsFrom: {sales, items, products},
    ).get();

    return results.map((r) => {
          'date': r.read<String?>('date') ?? '',
          'sizeKr': r.read<String?>('size_kr') ?? '',
          'platform': r.read<String?>('platform') ?? '',
          'sellPrice': r.read<int?>('sell_price') ?? 0,
          'settlementAmount': r.read<int?>('settlement_amount') ?? 0,
          'purchasePrice': r.read<int>('purchase_price'),
          'profit': r.read<int?>('profit') ?? 0,
        }).toList();
  }
}
