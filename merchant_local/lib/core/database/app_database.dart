import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

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
  int get schemaVersion => 5;

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
          if (from < 3) {
            // 컬럼 존재 여부 확인 후 추가 (재실행 안전)
            final cols = await customSelect(
              "PRAGMA table_info('items')",
              readsFrom: {},
            ).get();
            final hasCol = cols.any(
                (c) => c.read<String>('name') == 'poizon_storage_from');
            if (!hasCol) {
              await customStatement(
                  'ALTER TABLE items ADD COLUMN poizon_storage_from TEXT');
            }
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
          // v3 → v4: 인덱스 추가 (성능) + CASCADE 재설정은 새 DB에만 적용
          if (from < 4) {
            // 핵심 인덱스: items.current_status (가장 빈번한 필터)
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_items_status ON items (current_status)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_items_created ON items (created_at)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_items_updated ON items (updated_at)');
            // FK 컬럼 인덱스
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_status_logs_item ON status_logs (item_id)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_purchases_item ON purchases (item_id)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_sales_item ON sales (item_id)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_sale_adj_sale ON sale_adjustments (sale_id)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_inspections_item ON inspection_rejections (item_id)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_repairs_item ON repairs (item_id)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_shipments_item ON shipments (item_id)');
            // POIZON 캐시 테이블 인덱스
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_sku_article ON poizon_sku_cache (article_number)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_listings_status ON poizon_listings (status)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_orders_status ON poizon_orders (status)');
          }
          // v4 → v5: 16개 테이블에 hlc + is_deleted 추가 (CRDT 동기화 준비)
          if (from < 5) {
            const tables = [
              'brands', 'sources', 'products', 'size_charts',
              'items', 'purchases', 'sales', 'sale_adjustments',
              'status_logs', 'inspection_rejections', 'repairs', 'shipments',
              'supplier_returns', 'order_cancellations', 'sample_usages',
              'platform_fee_rules',
            ];
            for (final table in tables) {
              await customStatement(
                "ALTER TABLE $table ADD COLUMN hlc TEXT NOT NULL DEFAULT ''",
              );
              await customStatement(
                "ALTER TABLE $table ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0",
              );
            }
            // 디바이스 ID 초기 생성
            final deviceId = const Uuid().v4();
            await customStatement(
              "INSERT OR IGNORE INTO sync_meta (key, value, updated_at) "
              "VALUES ('device_id', '$deviceId', ${DateTime.now().millisecondsSinceEpoch})",
            );
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
    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        // WAL 모드: 읽기/쓰기 동시 처리, 필터 전환 중 blocking 제거
        db.execute('PRAGMA journal_mode=WAL');
        // 동기화 수준 완화: WAL 모드에서 안전하며 쓰기 속도 향상
        db.execute('PRAGMA synchronous=NORMAL');
        // 메모리 캐시 64MB: 자주 쓰는 쿼리 결과 재사용
        db.execute('PRAGMA cache_size=-65536');
        // 임시 테이블 메모리 처리: 집계 쿼리(대시보드 KPI 등) 속도 향상
        db.execute('PRAGMA temp_store=MEMORY');
        // WAL 체크포인트 자동화 (기본값 1000 → 500으로 낮춰 안정성 확보)
        db.execute('PRAGMA wal_autocheckpoint=500');
      },
    );
  });
}
