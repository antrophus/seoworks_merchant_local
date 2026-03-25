import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/app_database.dart';

/// 데이터 내보내기 서비스 (JSON / CSV)
class DataExportService {
  final AppDatabase db;

  DataExportService(this.db);

  /// 전체 DB를 JSON으로 내보내기
  Future<String> exportAllToJson() async {
    final data = <String, dynamic>{};

    data['brands'] = (await db.select(db.brands).get())
        .map((b) => b.toJson())
        .toList();
    data['products'] = (await db.select(db.products).get())
        .map((p) => p.toJson())
        .toList();
    data['items'] = (await db.select(db.items).get())
        .map((i) => i.toJson())
        .toList();
    data['purchases'] = (await db.select(db.purchases).get())
        .map((p) => p.toJson())
        .toList();
    data['sales'] = (await db.select(db.sales).get())
        .map((s) => s.toJson())
        .toList();
    data['sale_adjustments'] = (await db.select(db.saleAdjustments).get())
        .map((a) => a.toJson())
        .toList();
    data['status_logs'] = (await db.select(db.statusLogs).get())
        .map((l) => l.toJson())
        .toList();
    data['shipments'] = (await db.select(db.shipments).get())
        .map((s) => s.toJson())
        .toList();
    data['inspection_rejections'] =
        (await db.select(db.inspectionRejections).get())
            .map((r) => r.toJson())
            .toList();
    data['repairs'] = (await db.select(db.repairs).get())
        .map((r) => r.toJson())
        .toList();
    data['sources'] = (await db.select(db.sources).get())
        .map((s) => s.toJson())
        .toList();
    data['platform_fee_rules'] = (await db.select(db.platformFeeRules).get())
        .map((r) => r.toJson())
        .toList();
    data['supplier_returns'] = (await db.select(db.supplierReturns).get())
        .map((r) => r.toJson())
        .toList();
    data['order_cancellations'] =
        (await db.select(db.orderCancellations).get())
            .map((c) => c.toJson())
            .toList();
    data['sample_usages'] = (await db.select(db.sampleUsages).get())
        .map((s) => s.toJson())
        .toList();

    data['exported_at'] = DateTime.now().toIso8601String();

    final json = const JsonEncoder.withIndent('  ').convert(data);
    final file = await _writeToTempFile('merchant_backup.json', json);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    return file.path;
  }

  /// 판매 내역 CSV 내보내기
  Future<String> exportSalesCsv() async {
    final rows = await db.customSelect(
      '''SELECT pr.model_code, pr.model_name, i.sku, i.size_kr,
                s.platform, s.sell_price, s.platform_fee, s.settlement_amount,
                s.sale_date, p.purchase_price
         FROM sales s
         JOIN items i ON i.id = s.item_id
         JOIN products pr ON pr.id = i.product_id
         LEFT JOIN purchases p ON p.item_id = s.item_id
         WHERE i.current_status IN ('SOLD','SETTLED','DEFECT_SOLD','DEFECT_SETTLED')
         ORDER BY s.sale_date DESC''',
      readsFrom: {db.sales, db.items, db.products},
    ).get();

    final buf = StringBuffer();
    buf.writeln(
        '모델코드,모델명,SKU,사이즈,플랫폼,판매가,수수료,정산금,판매일,구매가,이익');
    for (final r in rows) {
      final sellPrice = r.readNullable<int>('sell_price') ?? 0;
      final purchasePrice = r.readNullable<int>('purchase_price') ?? 0;
      final settlement = r.readNullable<int>('settlement_amount') ?? 0;
      final profit = settlement - purchasePrice;
      buf.writeln([
        r.read<String>('model_code'),
        r.read<String>('model_name'),
        r.read<String>('sku'),
        r.read<String>('size_kr'),
        r.readNullable<String>('platform') ?? '',
        sellPrice,
        r.readNullable<int>('platform_fee') ?? 0,
        settlement,
        r.readNullable<String>('sale_date') ?? '',
        purchasePrice,
        profit,
      ].join(','));
    }

    final file = await _writeToTempFile('sales_export.csv', buf.toString());
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    return file.path;
  }

  /// 재고 현황 CSV 내보내기
  Future<String> exportInventoryCsv() async {
    final rows = await db.customSelect(
      '''SELECT pr.model_code, pr.model_name, i.sku, i.size_kr,
                i.current_status, i.barcode, i.is_personal,
                p.purchase_price, p.purchase_date, p.payment_method,
                s.platform, s.listed_price, s.sell_price
         FROM items i
         JOIN products pr ON pr.id = i.product_id
         LEFT JOIN purchases p ON p.item_id = i.id
         LEFT JOIN sales s ON s.item_id = i.id
         ORDER BY i.created_at DESC''',
      readsFrom: {db.items, db.products},
    ).get();

    final buf = StringBuffer();
    buf.writeln(
        '모델코드,모델명,SKU,사이즈,상태,바코드,개인용,구매가,구매일,결제수단,플랫폼,등록가,판매가');
    for (final r in rows) {
      buf.writeln([
        r.read<String>('model_code'),
        r.read<String>('model_name'),
        r.read<String>('sku'),
        r.read<String>('size_kr'),
        r.read<String>('current_status'),
        r.readNullable<String>('barcode') ?? '',
        r.read<bool>('is_personal') ? 'Y' : 'N',
        r.readNullable<int>('purchase_price') ?? '',
        r.readNullable<String>('purchase_date') ?? '',
        r.read<String>('payment_method'),
        r.readNullable<String>('platform') ?? '',
        r.readNullable<int>('listed_price') ?? '',
        r.readNullable<int>('sell_price') ?? '',
      ].join(','));
    }

    final file =
        await _writeToTempFile('inventory_export.csv', buf.toString());
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    return file.path;
  }

  Future<File> _writeToTempFile(String name, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(content);
    return file;
  }
}
