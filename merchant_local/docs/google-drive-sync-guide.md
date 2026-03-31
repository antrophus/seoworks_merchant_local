# Google Drive 동기화 구현 가이드

> 작성일: 2026-03-31
> 상태: 구현 예정 (Phase 3)
> 관련: `web-to-local-migration-plan.md` Sprint 5

---

## 1. 개요

### 목적
여러 디바이스에서 동일한 Google 계정으로 로그인하여 데이터를 자동 동기화한다.
CRDT(HLC) 기반 충돌 해결로 동시 편집을 안전하게 지원한다.

### 동기화 모델
- **동일 계정 방식**: 모든 디바이스에서 같은 Google 계정으로 로그인
- **저장소**: Google Drive `appDataFolder` (사용자에게 보이지 않는 숨김 폴더)
- **충돌 해결**: HLC(Hybrid Logical Clock) 비교 — 높은 값이 승리 (Last-Write-Wins)
- **오프라인 우선**: 네트워크 없이 모든 기능 동작, 연결 시 동기화

### 아키텍처 다이어그램

```
Device A (nodeId: abc)              Google Drive (appDataFolder)           Device B (nodeId: xyz)
┌──────────────────┐               ┌────────────────────────┐             ┌──────────────────┐
│ SQLite (Drift)   │── upload ───► │ sync_manifest.json     │◄── down ───│ SQLite (Drift)   │
│ + HLC per record │               │ data/brands.json       │             │ + HLC per record │
│                  │◄── down ───── │ data/items.json        │── upload ──►│                  │
│ HlcClockService  │               │ data/sales.json        │             │ HlcClockService  │
│ (device_id: abc) │               │ data/purchases.json    │             │ (device_id: xyz) │
└──────────────────┘               │ ...15개 테이블 파일     │             └──────────────────┘
                                   └────────────────────────┘
```

---

## 2. 현재 상태 (구현 전)

### 이미 준비된 것
- [x] `crdt: ^5.1.3` 패키지 (pubspec.yaml)
- [x] `google_sign_in: ^6.2.1` 패키지 (pubspec.yaml)
- [x] `googleapis: ^12.0.0` 패키지 (pubspec.yaml)
- [x] `SyncMeta` 테이블 (key-value 저장소, updatedAt 포함)
- [x] POIZON 캐시 3개 테이블에 `hlc` + `isDeleted` 컬럼 (참고용)
- [x] 모든 테이블 PK가 UUID (전역 고유 — 다중 디바이스 안전)
- [x] `DataExportService.exportAllToJson()` — 전체 DB JSON 내보내기 (직렬화 참고)
- [x] Settings 화면에 Phase 3 플레이스홀더 영역

### 구현 필요한 것
- [ ] 15개 메인 테이블에 `hlc` + `is_deleted` 컬럼 추가
- [ ] DB 마이그레이션 v4 → v5
- [ ] `HlcClockService` (디바이스별 고유 시계)
- [ ] 모든 DAO에 HLC 스탬프 + soft delete 로직
- [ ] `GoogleDriveService` (인증 + 파일 업/다운)
- [ ] `SyncEngine` (델타 감지 + 머지 + 업로드)
- [ ] UI (로그인, 동기화 상태, 수동/자동 동기화)

---

## 3. 구현 계획

### Phase 3-1: DB 스키마 마이그레이션 (v4 → v5)

#### 3-1-1. 테이블 컬럼 추가

15개 메인 테이블 + `platform_fee_rules`에 아래 2개 컬럼 추가:

```dart
// 각 테이블 정의 파일에 추가
TextColumn get hlc => text().withDefault(const Constant(''))();
BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
```

**대상 테이블 (16개):**

| # | 테이블 | 파일 경로 |
|---|--------|----------|
| 1 | Brands | `lib/core/database/tables/brand_table.dart` |
| 2 | Sources | `lib/core/database/tables/source_table.dart` |
| 3 | Products | `lib/core/database/tables/product_table.dart` |
| 4 | SizeCharts | `lib/core/database/tables/size_chart_table.dart` |
| 5 | Items | `lib/core/database/tables/item_table.dart` |
| 6 | Purchases | `lib/core/database/tables/purchase_table.dart` |
| 7 | Sales | `lib/core/database/tables/sale_table.dart` |
| 8 | SaleAdjustments | `lib/core/database/tables/sale_adjustment_table.dart` |
| 9 | StatusLogs | `lib/core/database/tables/status_log_table.dart` |
| 10 | InspectionRejections | `lib/core/database/tables/inspection_rejection_table.dart` |
| 11 | Repairs | `lib/core/database/tables/repair_table.dart` |
| 12 | Shipments | `lib/core/database/tables/shipment_table.dart` |
| 13 | SupplierReturns | `lib/core/database/tables/supplier_return_table.dart` |
| 14 | OrderCancellations | `lib/core/database/tables/order_cancellation_table.dart` |
| 15 | SampleUsages | `lib/core/database/tables/sample_usage_table.dart` |
| 16 | PlatformFeeRules | `lib/core/database/tables/platform_fee_rule_table.dart` |

#### 3-1-2. 마이그레이션 코드

`app_database.dart`에서 `schemaVersion`을 4 → 5로 변경하고 마이그레이션 추가:

```dart
// schemaVersion: 5

if (from < 5) {
  final tables = [
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
  // 디바이스 ID 생성
  await customStatement(
    "INSERT OR IGNORE INTO sync_meta (key, value, updated_at) "
    "VALUES ('device_id', '${const Uuid().v4()}', '${DateTime.now().toIso8601String()}')",
  );
}
```

#### 3-1-3. HLC 백필 (기존 데이터)

마이그레이션 후 기존 레코드에 HLC를 채워야 동기화에 참여 가능:

```dart
// 마이그레이션 완료 후 1회 실행
Future<void> backfillHlc(String deviceId) async {
  final tables = [...]; // 위와 동일
  for (final table in tables) {
    // createdAt이 있는 테이블은 해당 값 기반 HLC 생성
    // 없으면 현재 시각 사용
    final rows = await customSelect('SELECT id, created_at FROM $table WHERE hlc = ""').get();
    for (final row in rows) {
      final createdAt = DateTime.parse(row.read<String>('created_at'));
      final hlc = Hlc(createdAt, 0, deviceId);
      await customStatement(
        "UPDATE $table SET hlc = '${hlc.toString()}' WHERE id = '${row.read<String>('id')}'",
      );
    }
  }
}
```

#### 3-1-4. build_runner 재생성

```bash
cd merchant_local
dart run build_runner build --delete-conflicting-outputs
```

---

### Phase 3-2: HLC Clock Service

#### 새 파일: `lib/core/services/hlc_clock_service.dart`

```dart
import 'package:crdt/crdt.dart';
import 'package:uuid/uuid.dart';

class HlcClockService {
  late Hlc _canonicalTime;
  late String _nodeId;

  String get nodeId => _nodeId;
  Hlc get canonicalTime => _canonicalTime;

  /// SyncMeta에서 device_id를 읽어 초기화. 없으면 새로 생성.
  Future<void> init(AppDatabase db) async {
    final meta = await (db.select(db.syncMeta)
      ..where((t) => t.key.equals('device_id')))
      .getSingleOrNull();

    if (meta != null) {
      _nodeId = meta.value;
    } else {
      _nodeId = const Uuid().v4();
      await db.into(db.syncMeta).insert(SyncMetaCompanion.insert(
        key: 'device_id',
        value: _nodeId,
        updatedAt: DateTime.now(),
      ));
    }

    _canonicalTime = Hlc.now(_nodeId);
  }

  /// 로컬 쓰기 시 호출 — 단조 증가하는 HLC 반환
  Hlc increment() {
    _canonicalTime = _canonicalTime.increment();
    return _canonicalTime;
  }

  /// 리모트 HLC 수신 시 호출 — 시계 동기화
  void merge(Hlc remote) {
    _canonicalTime = _canonicalTime.merge(remote);
  }
}
```

#### Riverpod Provider 등록

`lib/core/providers.dart`에 추가:

```dart
final hlcClockProvider = Provider<HlcClockService>((ref) {
  throw UnimplementedError('hlcClockProvider must be overridden at startup');
});
```

#### main.dart 초기화

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  final clock = HlcClockService();
  await clock.init(db);
  db.hlcClock = clock; // AppDatabase에 clock 필드 추가 필요

  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      hlcClockProvider.overrideWithValue(clock),
    ],
    child: const MerchantApp(),
  ));
}
```

---

### Phase 3-3: DAO 수정 (HLC 스탬프 + Soft Delete)

#### 원칙

1. **모든 INSERT/UPDATE에 HLC 스탬프**: `db.hlcClock.increment().toString()`
2. **모든 SELECT에 `isDeleted` 필터**: `WHERE is_deleted = 0` (또는 `..where((t) => t.isDeleted.equals(false))`)
3. **하드 삭제 → 소프트 삭제 전환**: `isDeleted = true` + HLC 스탬프

#### 수정 대상 DAO 목록 (5개)

| DAO | 파일 | 주요 변경 |
|-----|------|----------|
| ItemDao | `daos/item_dao.dart` | insert/update/updateStatus에 HLC, 모든 쿼리에 isDeleted 필터, raw SQL 쿼리에 `AND is_deleted = 0` |
| MasterDao | `daos/master_dao.dart` | upsert 시 HLC, 브랜드/소스/상품/사이즈차트/수수료 쿼리에 필터 |
| PurchaseDao | `daos/purchase_dao.dart` | insert/update에 HLC, 쿼리 필터 |
| SaleDao | `daos/sale_dao.dart` | insert/update에 HLC, `deleteAdjustment` → soft delete, raw SQL 통계 쿼리에 `AND is_deleted = 0` |
| SubRecordDao | `daos/sub_record_dao.dart` | 모든 insert에 HLC, `deleteShipment` → soft delete |

#### Raw SQL 쿼리 수정 체크리스트

아래 메서드의 SQL에 `AND <alias>.is_deleted = 0` 추가 필요:

**ItemDao:**
- `getStatusCounts()` — `SELECT current_status, COUNT(*) ...`
- `getAssetSummary()` — `SELECT SUM(...) ...`
- `getTopBrands()` — `SELECT b.name, COUNT(*) ...`
- `getRecentActivities()` — `SELECT sl.*, i.sku ...`

**SaleDao:**
- `getSalesSummary()` — `SELECT COUNT(*), SUM(sell_price) ...`
- `getMonthlyTrend()` — `SELECT strftime(...), SUM(...) ...`
- `getPlatformDistribution()` — `SELECT platform, COUNT(*) ...`
- `getTopProfitModels()` / `getTopLossModels()`
- `getMonthlySales()` / `getThisMonthSales()` / `getLastMonthSales()`

**PurchaseDao:**
- `getPurchasesSummary()` — 통계 쿼리

---

### Phase 3-4: Google Drive Service

#### 사전 준비: Google Cloud Console 설정

1. [Google Cloud Console](https://console.cloud.google.com/) 프로젝트 생성
2. **Google Drive API** 활성화
3. **OAuth 2.0 클라이언트 ID** 생성:
   - Android: 패키지명 `com.seoworks.merchant_local` + SHA-1 인증서 지문
   - Web (Windows 데스크톱 폴백용): 리디렉트 URI `http://localhost`
4. Android: `google-services.json`을 `merchant_local/android/app/` 에 배치

#### 필요 패키지 추가 (pubspec.yaml)

```yaml
dependencies:
  extension_google_sign_in_as_googleapis_auth: ^2.0.12
  # google_sign_in, googleapis는 이미 있음
```

#### 새 파일: `lib/core/services/google_drive_service.dart`

```dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class GoogleDriveService {
  static const _scopes = ['https://www.googleapis.com/auth/drive.appdata'];

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);
  GoogleSignInAccount? _account;
  drive.DriveApi? _driveApi;

  bool get isSignedIn => _account != null;
  String? get accountEmail => _account?.email;
  String? get accountDisplayName => _account?.displayName;

  /// Google 로그인 (사용자 인터랙션)
  Future<bool> signIn() async {
    _account = await _googleSignIn.signIn();
    if (_account == null) return false;
    await _initDriveApi();
    return true;
  }

  /// 앱 시작 시 자동 로그인 시도 (UI 없음)
  Future<bool> trySilentSignIn() async {
    _account = await _googleSignIn.signInSilently();
    if (_account == null) return false;
    await _initDriveApi();
    return true;
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _account = null;
    _driveApi = null;
  }

  Future<void> _initDriveApi() async {
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient != null) {
      _driveApi = drive.DriveApi(httpClient);
    }
  }

  /// appDataFolder에 JSON 파일 업로드 (기존 파일 덮어쓰기)
  Future<void> uploadFile(String fileName, String jsonContent) async {
    final api = _driveApi!;
    final bytes = utf8.encode(jsonContent);
    final media = drive.Media(Stream.value(bytes), bytes.length);

    // 기존 파일 검색
    final existing = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$fileName'",
      $fields: 'files(id)',
    );

    if (existing.files?.isNotEmpty == true) {
      // 업데이트
      await api.files.update(
        drive.File(),
        existing.files!.first.id!,
        uploadMedia: media,
      );
    } else {
      // 새로 생성
      final driveFile = drive.File()
        ..name = fileName
        ..parents = ['appDataFolder'];
      await api.files.create(driveFile, uploadMedia: media);
    }
  }

  /// appDataFolder에서 JSON 파일 다운로드
  Future<String?> downloadFile(String fileName) async {
    final api = _driveApi!;
    final files = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$fileName'",
      $fields: 'files(id)',
    );

    if (files.files?.isEmpty != false) return null;

    final response = await api.files.get(
      files.files!.first.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  /// appDataFolder 파일 목록
  Future<List<drive.File>> listFiles() async {
    final result = await _driveApi!.files.list(
      spaces: 'appDataFolder',
      $fields: 'files(id, name, modifiedTime, size)',
    );
    return result.files ?? [];
  }
}
```

#### Windows 데스크톱 대응

`google_sign_in`은 Windows를 네이티브 지원하지 않음. 대안:

```dart
// lib/core/services/google_drive_service_desktop.dart
// googleapis_auth 패키지의 브라우저 기반 OAuth 사용
import 'package:googleapis_auth/auth_io.dart' as auth;

Future<auth.AutoRefreshingAuthClient> signInDesktop() async {
  final clientId = auth.ClientId('YOUR_CLIENT_ID', 'YOUR_CLIENT_SECRET');
  return auth.clientViaUserConsent(
    clientId,
    ['https://www.googleapis.com/auth/drive.appdata'],
    (url) => launchUrl(Uri.parse(url)), // url_launcher로 브라우저 열기
  );
}
```

`GoogleDriveService`에서 `Platform.isWindows`로 분기:
- Android/iOS → `google_sign_in` 사용
- Windows → `googleapis_auth` + 브라우저 OAuth 사용

---

### Phase 3-5: Sync Engine (핵심)

#### 새 파일: `lib/core/services/sync_engine.dart`

#### Sync Manifest 모델

```dart
class SyncManifest {
  final String schemaVersion; // "5" — 불일치 시 동기화 거부
  final Map<String, String> tableHlcs; // 테이블명 → max HLC
  final String lastSyncedAt; // ISO 8601
  final String lastSyncedBy; // device nodeId

  Map<String, dynamic> toJson() => { ... };
  factory SyncManifest.fromJson(Map<String, dynamic> json) => ...;
}
```

#### Google Drive 파일 구조

```
appDataFolder/
├── sync_manifest.json          ← 테이블별 최신 HLC + 메타데이터
├── data_brands.json            ← Brands 전체 레코드 (is_deleted 포함)
├── data_sources.json
├── data_products.json
├── data_size_charts.json
├── data_items.json
├── data_purchases.json
├── data_sales.json
├── data_sale_adjustments.json
├── data_status_logs.json
├── data_inspection_rejections.json
├── data_repairs.json
├── data_shipments.json
├── data_supplier_returns.json
├── data_order_cancellations.json
├── data_sample_usages.json
└── data_platform_fee_rules.json
```

#### 동기화 플로우 (SyncEngine.sync())

```
1. 로그인 확인 → 미로그인 시 중단

2. 리모트 manifest 다운로드
   ├── 없음 (최초) → 로컬 전체 업로드 (Step 6으로)
   └── 있음 → 스키마 버전 확인
       └── 불일치 → 에러 반환 ("모든 기기의 앱을 업데이트하세요")

3. 테이블별 HLC 비교 (다운로드 대상 결정)
   for each table:
     remoteHlc = manifest.tableHlcs[table]
     localMaxHlc = SELECT MAX(hlc) FROM <table>
     if remoteHlc > localMaxHlc → 다운로드 필요
     if localMaxHlc > remoteHlc → 업로드 필요
     if equal → 스킵

4. 변경된 테이블 다운로드 + CRDT 머지
   for each table needing download:
     remoteJson = driveService.downloadFile("data_<table>.json")
     remoteRecords = json.decode(remoteJson)
     _mergeRecords(table, remoteRecords)

5. CRDT 머지 알고리즘 (_mergeRecords)
   for each remoteRecord:
     local = db.getById(remoteRecord.id)
     if local == null:
       db.insertRaw(remoteRecord)  // 새 레코드
       clock.merge(Hlc.parse(remoteRecord.hlc))
     else:
       remoteHlc = Hlc.parse(remoteRecord.hlc)
       localHlc = Hlc.parse(local.hlc)
       if remoteHlc > localHlc:
         db.updateRaw(remoteRecord)  // 리모트 승리
         clock.merge(remoteHlc)
       // else: 로컬 승리 → 유지

6. 변경된 테이블 업로드
   for each table needing upload:
     allRecords = SELECT * FROM <table> WHERE hlc != ''
     jsonStr = json.encode(allRecords)  // is_deleted 포함
     driveService.uploadFile("data_<table>.json", jsonStr)

7. Manifest 업데이트 + 업로드
   manifest.tableHlcs = { table: localMaxHlc for each table }
   manifest.lastSyncedAt = DateTime.now().toIso8601String()
   manifest.lastSyncedBy = clock.nodeId
   driveService.uploadFile("sync_manifest.json", manifest.toJson())

8. SyncMeta에 마지막 동기화 시각 저장
   db.syncMeta.upsert('last_sync_at', DateTime.now())

9. Riverpod 상태 갱신
   ref.invalidate(itemsProvider)  // UI 새로고침
```

#### 머지 시 FK 의존성 순서 (반드시 준수)

```
다운로드+머지 순서 (부모 → 자식):
  1. brands
  2. sources
  3. platform_fee_rules
  4. products (FK: brands)
  5. size_charts
  6. items (FK: products)
  7. purchases (FK: items, sources)
  8. sales (FK: items)
  9. sale_adjustments (FK: sales)
  10. status_logs (FK: items)
  11. inspection_rejections (FK: items)
  12. repairs (FK: items)
  13. shipments (FK: items)
  14. supplier_returns (FK: items)
  15. order_cancellations (FK: items)
  16. sample_usages (FK: items)
```

#### 소프트 삭제 정리 (Garbage Collection)

동기화 시 90일 이상 경과한 `is_deleted = true` 레코드 하드 삭제:

```dart
Future<void> purgeOldDeletedRecords() async {
  final cutoff = DateTime.now().subtract(const Duration(days: 90));
  for (final table in syncableTables) {
    await customStatement(
      "DELETE FROM $table WHERE is_deleted = 1 AND hlc < '${cutoff.toIso8601String()}'",
    );
  }
}
```

---

### Phase 3-6: UI 변경

#### Settings 화면 Google Drive 섹션

`lib/features/settings/settings_screen.dart` — 기존 Phase 3 플레이스홀더 교체:

```
┌─────────────────────────────────────────────┐
│  ☁️  Google Drive 동기화                      │
│                                             │
│  [Google 아이콘] user@gmail.com              │
│  마지막 동기화: 3분 전                         │
│                                             │
│  [🔄 지금 동기화]  [자동 동기화: ON ▼]          │
│                                             │
│  자동 동기화 간격: [15분 ▼]                    │
│                                             │
│  [로그아웃]                                   │
└─────────────────────────────────────────────┘

미로그인 상태:
┌─────────────────────────────────────────────┐
│  ☁️  Google Drive 동기화                      │
│                                             │
│  [Google로 로그인]                            │
│                                             │
│  여러 기기에서 같은 Google 계정으로             │
│  로그인하면 데이터가 자동 동기화됩니다.          │
└─────────────────────────────────────────────┘
```

#### AppBar 동기화 인디케이터

`lib/features/home/home_screen.dart` AppBar에 아이콘 추가:

| 상태 | 아이콘 | 색상 |
|------|--------|------|
| 동기화 완료 | `Icons.cloud_done` | 초록 |
| 동기화 중 | `Icons.cloud_sync` (회전) | 파랑 |
| 오류 발생 | `Icons.cloud_off` | 빨강 |
| 미로그인 | `Icons.cloud_outlined` | 회색 |

#### Riverpod Providers

`lib/core/providers/sync_providers.dart` 신규:

```dart
// Google 계정 상태
final googleAccountProvider = StateProvider<GoogleSignInAccount?>((ref) => null);

// 동기화 상태 enum
enum SyncStatus { idle, syncing, success, error }
final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

// 마지막 동기화 시각
final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) async {
  final db = ref.read(databaseProvider);
  final meta = await (db.select(db.syncMeta)
    ..where((t) => t.key.equals('last_sync_at')))
    .getSingleOrNull();
  return meta != null ? DateTime.tryParse(meta.value) : null;
});

// SyncEngine 인스턴스
final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    db: ref.read(databaseProvider),
    driveService: ref.read(googleDriveServiceProvider),
    clock: ref.read(hlcClockProvider),
  );
});

// GoogleDriveService 인스턴스
final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  throw UnimplementedError('Override at startup');
});
```

---

### Phase 3-7: 자동 동기화 스케줄러

#### 새 파일: `lib/core/services/sync_scheduler.dart`

```dart
class SyncScheduler {
  Timer? _timer;
  final SyncEngine _engine;

  SyncScheduler(this._engine);

  void start(Duration interval) {
    stop();
    _timer = Timer.periodic(interval, (_) async {
      await _engine.sync();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  bool get isRunning => _timer?.isActive == true;
}
```

**main.dart에서 자동 동기화 시작:**

```dart
// Google 로그인 성공 후
if (driveService.isSignedIn) {
  final engine = SyncEngine(db: db, driveService: driveService, clock: clock);
  await engine.sync(); // 초기 동기화
  SyncScheduler(engine).start(const Duration(minutes: 15)); // 주기적 동기화
}
```

---

## 4. 에지 케이스 처리

| 시나리오 | 처리 방법 |
|---------|----------|
| 최초 동기화 (Drive 비어있음) | 로컬 전체 데이터 업로드, manifest 생성 |
| 새 기기 설치 (로컬 비어있음) | Drive에서 전체 다운로드 + 머지 |
| 스키마 버전 불일치 | 동기화 거부, "모든 기기 앱 업데이트" 메시지 |
| 네트워크 오류 중간 실패 | manifest 미업데이트 → 다음 동기화 시 재시도 |
| 두 기기 동시 동기화 | 마지막 upload이 manifest 덮어씀, 다음 sync에서 보정 |
| Google 토큰 만료 | `signInSilently()`로 자동 갱신 |
| UNIQUE 제약 충돌 (머지 중) | `insertOnConflictUpdate` 사용 — PK 기준 upsert |
| 소프트 삭제 레코드 누적 | 90일 경과 후 GC (동기화 시 실행) |

---

## 5. 파일 생성/수정 목록 (체크리스트)

### 새 파일 생성

| # | 파일 | 설명 |
|---|------|------|
| 1 | `lib/core/services/hlc_clock_service.dart` | HLC 시계 서비스 |
| 2 | `lib/core/services/google_drive_service.dart` | Google Drive 인증 + 파일 관리 |
| 3 | `lib/core/services/google_drive_service_desktop.dart` | Windows용 OAuth 폴백 |
| 4 | `lib/core/services/sync_engine.dart` | 동기화 엔진 (머지 + 업/다운) |
| 5 | `lib/core/services/sync_scheduler.dart` | 자동 동기화 타이머 |
| 6 | `lib/core/models/sync_manifest.dart` | SyncManifest 모델 |
| 7 | `lib/core/providers/sync_providers.dart` | 동기화 관련 Riverpod providers |

### 기존 파일 수정

| # | 파일 | 변경 내용 |
|---|------|----------|
| 1 | `pubspec.yaml` | `extension_google_sign_in_as_googleapis_auth` 추가 |
| 2 | 16개 테이블 파일 | `hlc` + `isDeleted` 컬럼 추가 |
| 3 | `app_database.dart` | schemaVersion 5, 마이그레이션, hlcClock 필드 |
| 4 | `daos/item_dao.dart` | HLC 스탬프, isDeleted 필터, raw SQL 수정 |
| 5 | `daos/master_dao.dart` | HLC 스탬프, isDeleted 필터 |
| 6 | `daos/purchase_dao.dart` | HLC 스탬프, isDeleted 필터 |
| 7 | `daos/sale_dao.dart` | HLC 스탬프, isDeleted 필터, deleteAdjustment → soft delete |
| 8 | `daos/sub_record_dao.dart` | HLC 스탬프, isDeleted 필터, deleteShipment → soft delete |
| 9 | `lib/core/providers.dart` | hlcClockProvider, googleDriveServiceProvider 추가 |
| 10 | `lib/main.dart` | HlcClock + GoogleDrive 초기화, 자동 동기화 |
| 11 | `lib/features/settings/settings_screen.dart` | Google Drive 섹션 UI |
| 12 | `lib/features/home/home_screen.dart` | AppBar 동기화 아이콘 |
| 13 | `android/app/build.gradle` | Google Services 플러그인 (필요 시) |
| 14 | `android/app/google-services.json` | OAuth 클라이언트 설정 (새 파일) |

---

## 6. 구현 순서 요약

```
Phase 3-1  DB 마이그레이션 ─────────────────────────── 기반 작업
  ├── 3-1-1  16개 테이블에 hlc + isDeleted 추가
  ├── 3-1-2  app_database.dart 마이그레이션 v4→v5
  ├── 3-1-3  기존 데이터 HLC 백필
  └── 3-1-4  build_runner 재생성

Phase 3-2  HLC Clock Service ──────────────────────── CRDT 핵심
  └── hlc_clock_service.dart + providers

Phase 3-3  DAO 수정 ───────────────────────────────── 가장 범위 넓음
  ├── 5개 DAO에 HLC 스탬프 추가
  ├── 모든 SELECT에 isDeleted 필터
  ├── 하드 삭제 → 소프트 삭제 전환
  └── Raw SQL 통계 쿼리 수정

Phase 3-4  Google Drive Service ───────────────────── 외부 연동
  ├── Google Cloud Console OAuth 설정
  ├── google_drive_service.dart (Android)
  └── google_drive_service_desktop.dart (Windows)

Phase 3-5  Sync Engine ───────────────────────────── 핵심 로직
  ├── sync_manifest.dart 모델
  ├── sync_engine.dart (머지 알고리즘)
  └── FK 의존성 순서 머지

Phase 3-6  UI ─────────────────────────────────────── 사용자 인터페이스
  ├── settings_screen.dart Google Drive 섹션
  ├── home_screen.dart AppBar 동기화 아이콘
  └── sync_providers.dart

Phase 3-7  자동 동기화 ────────────────────────────── 마무리
  ├── sync_scheduler.dart
  └── main.dart 초기화 흐름
```

---

## 7. 테스트 전략

| 테스트 | 내용 | 방법 |
|--------|------|------|
| HLC 단위 테스트 | increment() 단조 증가, merge() 시계 동기화, 문자열 직렬화 | `flutter test` |
| 머지 로직 테스트 | remote-wins, local-wins, 새 레코드, 소프트 삭제 전파 | 2개 DB 인스턴스로 시뮬레이션 |
| FK 순서 테스트 | 부모 없는 자식 레코드 머지 시 에러 없음 확인 | 순서 변경해서 실패 확인 |
| Drive 통합 테스트 | 실제 Google Drive 업/다운로드 | 테스트 계정 사용 |
| 마이그레이션 테스트 | v4 DB 생성 → v5 마이그레이션 → 기존 쿼리 정상 | 스냅샷 DB 파일 사용 |
| E2E 시나리오 | 기기 A에서 수정 → 동기화 → 기기 B에서 확인 | 에뮬레이터 2대 |

---

## 8. 주의사항

1. **Google Cloud Console OAuth 클라이언트 ID 필수** — Android SHA-1 + 패키지명 등록
2. **`google-services.json` 미포함 시 런타임 크래시** — 구현 전 반드시 준비
3. **Windows 데스크톱은 별도 OAuth 흐름** — `google_sign_in`이 Windows 미지원
4. **기존 raw SQL 쿼리 전수 검사** — `is_deleted = 0` 누락 시 삭제된 데이터 노출
5. **서명 키 분실 시 앱 재설치 필요** — 동기화가 있으므로 데이터 복구는 가능
6. **appDataFolder는 앱 제거 시 삭제됨** — Google Drive 앱 데이터 정책
