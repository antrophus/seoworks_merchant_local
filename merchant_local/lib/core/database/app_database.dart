import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// ── 마스터 테이블 ──
import 'tables/brand_table.dart';
import 'tables/source_table.dart';
import 'tables/product_table.dart';
import 'tables/size_chart_table.dart';

// ── 핵심 테이블 ──
import 'tables/item_table.dart';
import 'tables/purchase_table.dart';
import 'tables/sale_table.dart';
import 'tables/sale_adjustment_table.dart';

// ── 부속 테이블 ──
import 'tables/status_log_table.dart';
import 'tables/inspection_rejection_table.dart';
import 'tables/repair_table.dart';
import 'tables/shipment_table.dart';
import 'tables/supplier_return_table.dart';
import 'tables/order_cancellation_table.dart';
import 'tables/sample_usage_table.dart';

// ── 설정/로그 테이블 ──
import 'tables/platform_fee_rule_table.dart';
import 'tables/poizon_sync_log_table.dart';
import 'tables/sync_meta_table.dart';

// ── POIZON API 캐시 테이블 ──
import 'tables/sku_table.dart';
import 'tables/listing_table.dart';
import 'tables/order_table.dart';

// ── DAOs ──
import 'daos/sku_dao.dart';
import 'daos/listing_dao.dart';
import 'daos/order_dao.dart';
import 'daos/item_dao.dart';
import 'daos/purchase_dao.dart';
import 'daos/sale_dao.dart';
import 'daos/master_dao.dart';
import 'daos/sub_record_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    // 마스터
    Brands,
    Sources,
    Products,
    SizeCharts,
    // 핵심
    Items,
    Purchases,
    Sales,
    SaleAdjustments,
    // 부속
    StatusLogs,
    InspectionRejections,
    Repairs,
    Shipments,
    SupplierReturns,
    OrderCancellations,
    SampleUsages,
    // 설정/로그
    PlatformFeeRules,
    PoizonSyncLogs,
    SyncMeta,
    // POIZON API 캐시
    PoizonSkuCache,
    PoizonListings,
    PoizonOrders,
  ],
  daos: [
    SkuDao,
    ListingDao,
    OrderDao,
    ItemDao,
    PurchaseDao,
    SaleDao,
    MasterDao,
    SubRecordDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedPlatformFeeRules();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            final tables = allTables.toList().reversed;
            for (final table in tables) {
              await m.deleteTable(table.actualTableName);
            }
            await m.createAll();
            await _seedPlatformFeeRules();
          }
          // v2 → v3: items에 poizon_storage_from + 기존 정산 데이터 백필
          if (from >= 2 && from < 3) {
            await customStatement(
                'ALTER TABLE items ADD COLUMN poizon_storage_from TEXT');
            // 기존 SETTLED 아이템의 settledAt/saleDate 백필 (상태 변경 이력에서)
            await customStatement('''
              UPDATE sales SET
                settled_at = COALESCE(settled_at, (
                  SELECT changed_at FROM status_logs
                  WHERE status_logs.item_id = sales.item_id
                  AND status_logs.new_status IN ('SETTLED','DEFECT_SETTLED')
                  ORDER BY changed_at DESC LIMIT 1
                )),
                sale_date = COALESCE(sale_date, (
                  SELECT changed_at FROM status_logs
                  WHERE status_logs.item_id = sales.item_id
                  AND status_logs.new_status IN ('SETTLED','DEFECT_SETTLED')
                  ORDER BY changed_at DESC LIMIT 1
                ))
              WHERE item_id IN (
                SELECT id FROM items WHERE current_status IN ('SETTLED','DEFECT_SETTLED')
              ) AND settled_at IS NULL
            ''');
          }
        },
      );

  /// 플랫폼 수수료 규칙 초기 데이터
  Future<void> _seedPlatformFeeRules() async {
    final rules = [
      ('POIZON', 'default', 0.10, 15000, 45000, '신발·의류·기타'),
      ('POIZON', 'bag', 0.14, 18000, 45000, '가방·캐리어'),
      ('POIZON', 'bags', 0.14, 18000, 45000, '가방(복수형)'),
      ('POIZON', 'carrier', 0.14, 18000, 45000, '캐리어'),
      ('POIZON', 'acc', 0.14, 18000, 45000, '악세사리(약어)'),
      ('POIZON', 'accessories', 0.14, 18000, 45000, '악세사리류'),
      ('POIZON', 'accessory', 0.14, 18000, 45000, '악세사리(단수)'),
      ('POIZON', 'watch', 0.14, 18000, 45000, '시계류'),
      ('POIZON', 'watches', 0.14, 18000, 45000, '시계류(복수형)'),
    ];

    await batch((b) {
      for (var i = 0; i < rules.length; i++) {
        final r = rules[i];
        b.insert(
          platformFeeRules,
          PlatformFeeRulesCompanion.insert(
            id: 'seed-fee-rule-${i + 1}',
            platform: r.$1,
            category: Value(r.$2),
            feeRate: r.$3,
            minFee: Value(r.$4),
            maxFee: Value(r.$5),
            note: Value(r.$6),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'merchant_local', 'app_data.sqlite'));
    await file.parent.create(recursive: true);
    return NativeDatabase.createInBackground(file);
  });
}
