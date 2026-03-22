import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:logger/logger.dart';
import '../database/app_database.dart';

final _log = Logger(printer: SimplePrinter());

/// 임포트 진행 상태 콜백
typedef ImportProgressCallback = void Function(String tableName, int count, int total);

/// Supabase 백업 JSON → 로컬 Drift DB 임포트 서비스
class DataImportService {
  final AppDatabase db;

  DataImportService(this.db);

  /// 파일 맵에서 임포트 (Android용 — file_picker로 선택한 파일들)
  /// [fileMap] — { 'brands': '/cache/brands.json', ... }
  Future<ImportResult> importFromFiles(
    Map<String, String> fileMap, {
    ImportProgressCallback? onProgress,
  }) async {
    final result = ImportResult(success: true);
    var step = 0;
    const totalSteps = 15;

    try {
      Future<void> imp<T>(String name, T Function(Map<String, dynamic>) parser, Future<void> Function(List<T>) inserter) async {
        step++;
        final path = fileMap[name];
        if (path == null) { result.tableResults[name] = 0; return; }
        await _importFromFile<T>(path, name, parser, inserter, result, step, totalSteps, onProgress);
      }

      await imp('brands', _parseBrand, (e) => db.masterDao.insertAllBrands(e));
      await imp('sources', _parseSource, (e) => db.masterDao.insertAllSources(e));
      await imp('products', _parseProduct, (e) => db.masterDao.insertAllProducts(e));
      await imp('size_charts', _parseSizeChart, (e) => db.masterDao.insertAllSizeCharts(e));
      await imp('items', _parseItem, (e) => db.itemDao.insertAll(e));
      await imp('purchases', _parsePurchase, (e) => db.purchaseDao.insertAll(e));
      await imp('sales', _parseSale, (e) => db.saleDao.insertAll(e));
      await imp('sale_adjustments', _parseSaleAdjustment, (e) => db.saleDao.insertAllAdjustments(e));
      await imp('status_logs', _parseStatusLog, (e) => db.subRecordDao.insertAllStatusLogs(e));
      await imp('inspection_rejections', _parseInspectionRejection, (e) => db.subRecordDao.insertAllInspectionRejections(e));
      await imp('repairs', _parseRepair, (e) => db.subRecordDao.insertAllRepairs(e));
      await imp('shipments', _parseShipment, (e) => db.subRecordDao.insertAllShipments(e));
      await imp('supplier_returns', _parseSupplierReturn, (e) => db.subRecordDao.insertAllSupplierReturns(e));
      await imp('order_cancellations', _parseOrderCancellation, (e) => db.subRecordDao.insertAllOrderCancellations(e));
      await imp('sample_usages', _parseSampleUsage, (e) => db.subRecordDao.insertAllSampleUsages(e));
    } catch (e, st) {
      _log.e('Import failed', error: e, stackTrace: st);
      result.success = false;
      result.error = e.toString();
    }

    return result;
  }

  /// 개별 파일 임포트 헬퍼
  Future<void> _importFromFile<T>(
    String filePath,
    String tableName,
    T Function(Map<String, dynamic>) parser,
    Future<void> Function(List<T>) inserter,
    ImportResult result,
    int step,
    int totalSteps,
    ImportProgressCallback? onProgress,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) {
      _log.w('$tableName file not found: $filePath');
      result.tableResults[tableName] = 0;
      return;
    }

    final jsonStr = await file.readAsString();
    final List<dynamic> rows = jsonDecode(jsonStr);

    final entries = <T>[];
    var skipped = 0;
    for (final row in rows) {
      try {
        entries.add(parser(row as Map<String, dynamic>));
      } catch (e) {
        skipped++;
        _log.w('$tableName parse error: $e');
      }
    }

    if (entries.isNotEmpty) {
      await inserter(entries);
    }

    result.tableResults[tableName] = entries.length;
    if (skipped > 0) result.tableSkipped[tableName] = skipped;
    onProgress?.call(tableName, step, totalSteps);
    _log.i('$tableName: ${entries.length} imported, $skipped skipped');
  }

  /// 백업 폴더에서 전체 데이터 임포트 (Windows용 — 폴더 경로 직접 접근)
  /// [backupDir] — JSON 파일들이 있는 폴더 경로
  Future<ImportResult> importFromBackupDir(
    String backupDir, {
    ImportProgressCallback? onProgress,
  }) async {
    final dir = Directory(backupDir);
    if (!await dir.exists()) {
      return ImportResult(success: false, error: '폴더를 찾을 수 없습니다: $backupDir');
    }

    final result = ImportResult(success: true);
    var step = 0;
    const totalSteps = 10; // 최대 테이블 수

    try {
      // FK 의존성 순서대로 임포트
      step++;
      await _importTable<BrandsCompanion>(
        dir, 'brands', _parseBrand, (entries) => db.masterDao.insertAllBrands(entries),
        result, step, totalSteps, onProgress,
      );

      step++;
      await _importTable<SourcesCompanion>(
        dir, 'sources', _parseSource, (entries) => db.masterDao.insertAllSources(entries),
        result, step, totalSteps, onProgress,
      );

      step++;
      await _importTable<ProductsCompanion>(
        dir, 'products', _parseProduct, (entries) => db.masterDao.insertAllProducts(entries),
        result, step, totalSteps, onProgress,
      );

      step++;
      await _importTable<SizeChartsCompanion>(
        dir, 'size_charts', _parseSizeChart, (entries) => db.masterDao.insertAllSizeCharts(entries),
        result, step, totalSteps, onProgress,
      );

      step++;
      await _importTable<ItemsCompanion>(
        dir, 'items', _parseItem, (entries) => db.itemDao.insertAll(entries),
        result, step, totalSteps, onProgress,
      );

      step++;
      await _importTable<PurchasesCompanion>(
        dir, 'purchases', _parsePurchase, (entries) => db.purchaseDao.insertAll(entries),
        result, step, totalSteps, onProgress,
      );

      step++;
      await _importTable<SalesCompanion>(
        dir, 'sales', _parseSale, (entries) => db.saleDao.insertAll(entries),
        result, step, totalSteps, onProgress,
      );

      step++;
      await _importTable<SaleAdjustmentsCompanion>(
        dir, 'sale_adjustments', _parseSaleAdjustment,
        (entries) => db.saleDao.insertAllAdjustments(entries),
        result, step, totalSteps, onProgress,
      );

      step++;
      await _importTable<StatusLogsCompanion>(
        dir, 'status_logs', _parseStatusLog, (entries) => db.subRecordDao.insertAllStatusLogs(entries),
        result, step, totalSteps, onProgress,
      );

      // 선택적 테이블 (백업에 없을 수 있음)
      step++;
      await _importTable<InspectionRejectionsCompanion>(
        dir, 'inspection_rejections', _parseInspectionRejection,
        (entries) => db.subRecordDao.insertAllInspectionRejections(entries),
        result, step, totalSteps, onProgress,
      );

      await _importTable<RepairsCompanion>(
        dir, 'repairs', _parseRepair,
        (entries) => db.subRecordDao.insertAllRepairs(entries),
        result, step, totalSteps, onProgress,
      );

      await _importTable<ShipmentsCompanion>(
        dir, 'shipments', _parseShipment,
        (entries) => db.subRecordDao.insertAllShipments(entries),
        result, step, totalSteps, onProgress,
      );

      await _importTable<SupplierReturnsCompanion>(
        dir, 'supplier_returns', _parseSupplierReturn,
        (entries) => db.subRecordDao.insertAllSupplierReturns(entries),
        result, step, totalSteps, onProgress,
      );

      await _importTable<OrderCancellationsCompanion>(
        dir, 'order_cancellations', _parseOrderCancellation,
        (entries) => db.subRecordDao.insertAllOrderCancellations(entries),
        result, step, totalSteps, onProgress,
      );

      await _importTable<SampleUsagesCompanion>(
        dir, 'sample_usages', _parseSampleUsage,
        (entries) => db.subRecordDao.insertAllSampleUsages(entries),
        result, step, totalSteps, onProgress,
      );
    } catch (e, st) {
      _log.e('Import failed', error: e, stackTrace: st);
      result.success = false;
      result.error = e.toString();
    }

    return result;
  }

  /// 개별 테이블 임포트 헬퍼
  Future<void> _importTable<T>(
    Directory dir,
    String tableName,
    T Function(Map<String, dynamic>) parser,
    Future<void> Function(List<T>) inserter,
    ImportResult result,
    int step,
    int totalSteps,
    ImportProgressCallback? onProgress,
  ) async {
    final file = File('${dir.path}/$tableName.json');
    if (!await file.exists()) {
      _log.w('$tableName.json not found, skipping');
      result.tableResults[tableName] = 0;
      return;
    }

    final jsonStr = await file.readAsString();
    final List<dynamic> rows = jsonDecode(jsonStr);

    final entries = <T>[];
    var skipped = 0;
    for (final row in rows) {
      try {
        entries.add(parser(row as Map<String, dynamic>));
      } catch (e) {
        skipped++;
        _log.w('$tableName parse error: $e');
      }
    }

    if (entries.isNotEmpty) {
      await inserter(entries);
    }

    result.tableResults[tableName] = entries.length;
    if (skipped > 0) result.tableSkipped[tableName] = skipped;
    onProgress?.call(tableName, step, totalSteps);
    _log.i('$tableName: ${entries.length} imported, $skipped skipped');
  }

  // ── 파서 함수들 ──

  BrandsCompanion _parseBrand(Map<String, dynamic> j) => BrandsCompanion.insert(
        id: j['id'] as String,
        name: j['name'] as String,
        code: Value(j['code'] as String?),
        createdAt: Value(j['created_at'] as String?),
      );

  SourcesCompanion _parseSource(Map<String, dynamic> j) => SourcesCompanion.insert(
        id: j['id'] as String,
        name: j['name'] as String,
        type: Value(j['type'] as String?),
        url: Value(j['url'] as String?),
        createdAt: Value(j['created_at'] as String?),
      );

  ProductsCompanion _parseProduct(Map<String, dynamic> j) => ProductsCompanion.insert(
        id: j['id'] as String,
        modelCode: j['model_code'] as String,
        modelName: j['model_name'] as String,
        brandId: Value(j['brand_id'] as String?),
        gender: Value(j['gender'] as String?),
        category: Value(j['category'] as String?),
        imageUrl: Value(j['image_url'] as String?),
        poizonSpuId: Value(j['poizon_spu_id'] as String?),
        createdAt: Value(j['created_at'] as String?),
      );

  SizeChartsCompanion _parseSizeChart(Map<String, dynamic> j) => SizeChartsCompanion.insert(
        id: j['id'] as String,
        brand: j['brand'] as String,
        target: j['target'] as String,
        kr: (j['kr'] as num).toDouble(),
        eu: Value(j['eu'] as String?),
        usM: Value(j['us_m'] as String?),
        usW: Value(j['us_w'] as String?),
        us: Value(j['us'] as String?),
        uk: Value(j['uk'] as String?),
        jp: Value(j['jp'] as String?),
        createdAt: Value(j['created_at'] as String?),
      );

  ItemsCompanion _parseItem(Map<String, dynamic> j) => ItemsCompanion.insert(
        id: j['id'] as String,
        productId: j['product_id'] as String,
        sku: j['sku'] as String,
        sizeKr: j['size_kr'] as String,
        sizeEu: Value(j['size_eu'] as String?),
        sizeUs: Value(j['size_us'] as String?),
        sizeEtc: Value(j['size_etc'] as String?),
        barcode: Value(j['barcode'] as String?),
        trackingNumber: Value(j['tracking_number'] as String?),
        isPersonal: Value(j['is_personal'] == true),
        currentStatus: Value(j['current_status'] as String? ?? 'OFFICE_STOCK'),
        location: Value(j['location'] as String?),
        defectNote: Value(j['defect_note'] as String?),
        note: Value(j['note'] as String?),
        poizonSkuId: Value(j['poizon_sku_id'] as String?),
        createdAt: Value(j['created_at'] as String?),
        updatedAt: Value(j['updated_at'] as String?),
      );

  PurchasesCompanion _parsePurchase(Map<String, dynamic> j) => PurchasesCompanion.insert(
        id: j['id'] as String,
        itemId: j['item_id'] as String,
        purchaseDate: Value(j['purchase_date'] as String?),
        purchasePrice: Value(_toInt(j['purchase_price'])),
        paymentMethod: Value(j['payment_method'] as String? ?? 'PERSONAL_CARD'),
        sourceId: Value(j['source_id'] as String?),
        vatRefundable: Value(_toDouble(j['vat_refundable'])),
        receiptUrl: Value(j['receipt_url'] as String?),
        memo: Value(j['memo'] as String?),
        createdAt: Value(j['created_at'] as String?),
      );

  SalesCompanion _parseSale(Map<String, dynamic> j) => SalesCompanion.insert(
        id: j['id'] as String,
        itemId: j['item_id'] as String,
        platform: j['platform'] as String,
        saleDate: Value(j['sale_date'] as String?),
        platformOption: Value(j['platform_option'] as String?),
        listedPrice: Value(_toInt(j['listed_price'])),
        sellPrice: Value(_toInt(j['sell_price'])),
        platformFeeRate: Value(_toDouble(j['platform_fee_rate'])),
        platformFee: Value(_toInt(j['platform_fee'])),
        settlementAmount: Value(_toInt(j['settlement_amount'])),
        adjustmentTotal: Value(_toInt(j['adjustment_total']) ?? 0),
        outgoingDate: Value(j['outgoing_date'] as String?),
        shipmentDeadline: Value(j['shipment_deadline'] as String?),
        trackingNumber: Value(j['tracking_number'] as String?),
        settledAt: Value(j['settled_at'] as String?),
        memo: Value(j['memo'] as String?),
        poizonOrderId: Value(j['poizon_order_id'] as String?),
        dataSource: Value(j['data_source'] as String? ?? 'manual'),
        createdAt: Value(j['created_at'] as String?),
      );

  SaleAdjustmentsCompanion _parseSaleAdjustment(Map<String, dynamic> j) =>
      SaleAdjustmentsCompanion.insert(
        id: j['id'] as String,
        saleId: j['sale_id'] as String,
        type: j['type'] as String,
        amount: _toInt(j['amount']) ?? 0,
        memo: Value(j['memo'] as String?),
        createdAt: Value(j['created_at'] as String?),
      );

  StatusLogsCompanion _parseStatusLog(Map<String, dynamic> j) => StatusLogsCompanion.insert(
        id: j['id'] as String,
        itemId: j['item_id'] as String,
        newStatus: j['new_status'] as String,
        oldStatus: Value(j['old_status'] as String?),
        note: Value(j['note'] as String?),
        changedAt: Value(j['changed_at'] as String?),
      );

  InspectionRejectionsCompanion _parseInspectionRejection(Map<String, dynamic> j) =>
      InspectionRejectionsCompanion.insert(
        id: j['id'] as String,
        itemId: j['item_id'] as String,
        returnSeq: j['return_seq'] as int,
        rejectedAt: j['rejected_at'] as String,
        reason: Value(j['reason'] as String?),
        photoUrls: Value(_jsonEncode(j['photo_urls'])),
        platform: Value(j['platform'] as String?),
        memo: Value(j['memo'] as String?),
        defectType: Value(j['defect_type'] as String?),
        discountAmount: Value(_toInt(j['discount_amount'])),
        createdAt: Value(j['created_at'] as String?),
      );

  RepairsCompanion _parseRepair(Map<String, dynamic> j) => RepairsCompanion.insert(
        id: j['id'] as String,
        itemId: j['item_id'] as String,
        startedAt: j['started_at'] as String,
        createdAt: j['created_at'] as String,
        completedAt: Value(j['completed_at'] as String?),
        repairCost: Value(_toInt(j['repair_cost'])),
        repairNote: Value(j['repair_note'] as String?),
        outcome: Value(j['outcome'] as String?),
      );

  ShipmentsCompanion _parseShipment(Map<String, dynamic> j) => ShipmentsCompanion.insert(
        id: j['id'] as String,
        itemId: j['item_id'] as String,
        seq: j['seq'] as int,
        trackingNumber: j['tracking_number'] as String,
        outgoingDate: Value(j['outgoing_date'] as String?),
        platform: Value(j['platform'] as String?),
        memo: Value(j['memo'] as String?),
        createdAt: Value(j['created_at'] as String?),
      );

  SupplierReturnsCompanion _parseSupplierReturn(Map<String, dynamic> j) =>
      SupplierReturnsCompanion.insert(
        id: j['id'] as String,
        itemId: j['item_id'] as String,
        returnedAt: j['returned_at'] as String,
        reason: Value(j['reason'] as String?),
        memo: Value(j['memo'] as String?),
        createdAt: Value(j['created_at'] as String?),
      );

  OrderCancellationsCompanion _parseOrderCancellation(Map<String, dynamic> j) =>
      OrderCancellationsCompanion.insert(
        id: j['id'] as String,
        itemId: j['item_id'] as String,
        cancelledAt: j['cancelled_at'] as String,
        reason: Value(j['reason'] as String?),
        memo: Value(j['memo'] as String?),
        createdAt: Value(j['created_at'] as String?),
      );

  SampleUsagesCompanion _parseSampleUsage(Map<String, dynamic> j) =>
      SampleUsagesCompanion.insert(
        id: j['id'] as String,
        itemId: j['item_id'] as String,
        purpose: j['purpose'] as String,
        usedAt: Value(j['used_at'] as String?),
        memo: Value(j['memo'] as String?),
        createdAt: Value(j['created_at'] as String?),
      );

  // ── 유틸 ──

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  String? _jsonEncode(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return jsonEncode(v);
  }
}

/// 임포트 결과
class ImportResult {
  bool success;
  String? error;
  final Map<String, int> tableResults = {};
  final Map<String, int> tableSkipped = {};

  ImportResult({required this.success, this.error});

  int get totalImported => tableResults.values.fold(0, (a, b) => a + b);
  int get totalSkipped => tableSkipped.values.fold(0, (a, b) => a + b);

  String get summary {
    final buf = StringBuffer();
    buf.writeln('임포트 완료: $totalImported건');
    for (final e in tableResults.entries) {
      if (e.value > 0) {
        final skip = tableSkipped[e.key];
        buf.write('  ${e.key}: ${e.value}건');
        if (skip != null && skip > 0) buf.write(' (스킵: $skip)');
        buf.writeln();
      }
    }
    if (totalSkipped > 0) buf.writeln('총 스킵: $totalSkipped건');
    if (error != null) buf.writeln('오류: $error');
    return buf.toString();
  }
}
