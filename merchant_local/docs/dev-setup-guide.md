# 온디바이스 앱 개발환경 구축 가이드

> Flutter + Google Drive Sync + CRDT
> 플랫폼: Windows (Desktop) + Android
> 데이터 전략: 완전 로컬 저장 + 선택적 Google Drive 동기화

---

## 1. 프로젝트 개요

### 핵심 원칙
- **데이터 주권**: 모든 데이터는 사용자 기기에 로컬 저장 (SQLite)
- **동기화**: 개발자 서버 없이 사용자의 Google Drive를 통해 기기 간 동기화
- **충돌 해결**: CRDT(Conflict-free Replicated Data Types)로 자동 병합
- **단일 코드베이스**: Flutter로 Windows + Android 동시 개발

### 기술 스택 요약

| 역할 | 기술 | 설명 |
|------|------|------|
| 외부 API 연동 | POIZON Open API | 셀러 계정 상품/주문/정산 데이터 동기화 |
| UI 프레임워크 | Flutter 3.x | Windows + Android 단일 코드 |
| 로컬 DB | Drift (SQLite) | 타입 안전한 SQLite ORM |
| 충돌 해결 | crdt 패키지 | CRDT 타임스탬프 기반 병합 |
| 동기화 저장소 | Google Drive appDataFolder | 사용자 전용 앱 폴더 (비공개) |
| 인증 | google_sign_in | OAuth 2.0 |
| 상태 관리 | Riverpod | 반응형 상태 관리 |
| 직렬화 | freezed + json_serializable | 불변 데이터 클래스 |

---

## 2. 개발 환경 요구사항

### 2-1. Flutter SDK 설치

```bash
# Flutter 공식 설치 (Windows)
# https://docs.flutter.dev/get-started/install/windows

# 설치 확인
flutter --version   # 3.19.0 이상 권장
flutter doctor      # 환경 점검
```

**필수 체크 항목 (flutter doctor)**
- [x] Flutter SDK
- [x] Android toolchain (Android Studio + SDK)
- [x] Visual Studio (Windows 앱 빌드용) — Community 버전 가능
- [x] Android 기기 또는 에뮬레이터

### 2-2. Android Studio 설치

1. [Android Studio](https://developer.android.com/studio) 설치
2. SDK Manager에서 설치:
   - Android SDK Platform 34 (API 34)
   - Android SDK Build-Tools 34.x
   - Android Emulator
3. AVD Manager에서 가상 기기 생성 (테스트용)

### 2-3. Visual Studio (Windows 빌드용)

1. [Visual Studio Community](https://visualstudio.microsoft.com/) 설치
2. 워크로드에서 **"C++를 사용한 데스크톱 개발"** 선택
3. Flutter Windows 앱 빌드 활성화:

```bash
flutter config --enable-windows-desktop
```

### 2-4. IDE

- **VS Code** (권장) + Flutter/Dart 확장 설치
- **Android Studio** (대안)

---

## 3. 프로젝트 생성

```bash
# 프로젝트 생성
flutter create --org com.yourname --platforms android,windows your_app_name
cd your_app_name

# 플랫폼 지원 확인
flutter devices
```

---

## 4. 핵심 패키지 설정

### pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter

  # 로컬 데이터베이스
  drift: ^2.15.0
  sqlite3_flutter_libs: ^0.5.18
  path_provider: ^2.1.2
  path: ^1.9.0

  # CRDT (충돌 해결)
  crdt: ^3.2.0

  # Google Drive 동기화
  google_sign_in: ^6.2.1
  googleapis: ^12.0.0
  http: ^1.2.0

  # 상태 관리
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.4

  # 직렬화
  freezed_annotation: ^2.4.1
  json_annotation: ^4.9.0

  # 유틸리티
  uuid: ^4.3.3
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter

  # 코드 생성
  build_runner: ^2.4.9
  drift_dev: ^2.15.0
  freezed: ^2.5.2
  json_serializable: ^6.8.0
  riverpod_generator: ^2.4.0
```

```bash
# 패키지 설치
flutter pub get

# 코드 생성 (drift, freezed, riverpod)
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 5. 프로젝트 구조

```
your_app_name/
├── lib/
│   ├── main.dart
│   ├── app.dart                    # 앱 진입점, 라우팅
│   │
│   ├── core/                       # 공통 핵심 모듈
│   │   ├── database/
│   │   │   ├── app_database.dart   # Drift DB 정의
│   │   │   ├── app_database.g.dart # 자동 생성
│   │   │   └── tables/             # 테이블 정의
│   │   ├── sync/
│   │   │   ├── sync_service.dart   # 동기화 오케스트레이션
│   │   │   ├── gdrive_service.dart # Google Drive API 래퍼
│   │   │   └── crdt_merger.dart    # CRDT 병합 로직
│   │   └── models/                 # freezed 데이터 모델
│   │
│   ├── features/                   # 기능별 모듈
│   │   ├── auth/                   # Google 로그인 (선택적)
│   │   ├── home/                   # 홈 화면
│   │   └── settings/               # 설정 (동기화 설정 등)
│   │
│   └── shared/                     # 공유 위젯, 유틸
│
├── android/                        # Android 플랫폼 설정
├── windows/                        # Windows 플랫폼 설정
├── test/                           # 단위 테스트
└── pubspec.yaml
```

---

## 6. 데이터 아키텍처

### 로컬 저장 (Drift + SQLite)

```dart
// lib/core/database/app_database.dart

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// 테이블 예시 - CRDT 메타데이터 포함
class Items extends Table {
  TextColumn get id => text()();              // UUID
  TextColumn get content => text()();
  TextColumn get hlc => text()();            // CRDT 타임스탬프 (Hybrid Logical Clock)
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Items])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app_data.sqlite'));
    return NativeDatabase(file);
  });
}
```

### CRDT 동기화 흐름

```
[기기 A - Windows]                    [기기 B - Android]
      │                                      │
      │  1. 로컬 수정 → CRDT HLC 타임스탬프 기록    │
      │                                      │
      │  2. JSON 직렬화 → Google Drive 업로드    │
      │         ↘                   ↙        │
      │          [Google Drive appDataFolder] │
      │         ↗                   ↖        │
      │  3. 변경 감지 → Drive에서 다운로드         │
      │                                      │
      │  4. CRDT 병합 → 충돌 자동 해결           │
      │                                      │
      └──────── 두 기기 데이터 일치 ────────────┘
```

### Google Drive appDataFolder

- 사용자에게 **보이지 않는** 앱 전용 폴더 (Drive UI에서 숨겨짐)
- 앱 삭제 시 자동 삭제
- 용량: 기본 10GB 한도 내

```dart
// Google Drive 파일 구조
appDataFolder/
├── metadata.json        # 마지막 동기화 정보
└── data_snapshot.json   # 전체 데이터 스냅샷 (CRDT 메타포함)
```

---

## 7. Google Cloud Console 설정

### 7-1. 프로젝트 생성 및 API 활성화

1. [Google Cloud Console](https://console.cloud.google.com) 접속
2. 새 프로젝트 생성
3. **API 및 서비스 > 라이브러리**에서 활성화:
   - `Google Drive API`
4. **OAuth 동의 화면** 구성:
   - 앱 이름, 이메일 입력
   - 범위 추가: `https://www.googleapis.com/auth/drive.appdata`

### 7-2. OAuth 클라이언트 ID 생성

| 플랫폼 | 애플리케이션 유형 |
|--------|----------------|
| Android | Android |
| Windows | 데스크톱 앱 |

**Android 설정:**
```bash
# SHA-1 인증서 지문 확인 (디버그)
cd android
./gradlew signingReport
```

`android/app/build.gradle`에 패키지명 확인 후 Cloud Console에 등록

### 7-3. 설정 파일 배치

```
android/app/
└── google-services.json    # Android OAuth 설정

windows/
└── google_client_id.txt    # Windows 클라이언트 ID (환경변수 권장)
```

---

## 8. Android 권한 설정

`android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
    <!-- 인터넷 (Google Drive 동기화용) -->
    <uses-permission android:name="android.permission.INTERNET" />

    <application ...>
        <!-- google_sign_in 필수 -->
        <meta-data
            android:name="com.google.android.gms.version"
            android:value="@integer/google_play_services_version" />
    </application>
</manifest>
```

---

## 9. Windows 빌드 설정

`windows/runner/main.cpp` — 기본값 유지

`windows/CMakeLists.txt`에서 앱 이름 확인:
```cmake
set(BINARY_NAME "your_app_name")
```

---

## 10. 개발 & 빌드 명령어

```bash
# 개발 실행
flutter run -d windows          # Windows 앱 실행
flutter run -d android          # Android 기기/에뮬레이터 실행

# 코드 생성 (모델/DB 변경 시마다 실행)
flutter pub run build_runner watch   # 파일 변경 감지 자동 재생성
flutter pub run build_runner build --delete-conflicting-outputs

# 빌드 (배포용)
flutter build windows           # Windows .exe 빌드 → build/windows/
flutter build apk --release     # Android APK → build/app/outputs/apk/
flutter build appbundle         # Google Play 배포용

# 테스트
flutter test                    # 단위 테스트
flutter test integration_test   # 통합 테스트
```

---

---

## 12. POIZON Open API 연동

> 셀러 계정의 포이즌 서버 데이터를 로컬 앱과 동기화하는 레이어.
> 개발자 서버 없이 앱이 직접 POIZON API를 호출하고, 결과는 로컬 SQLite에 저장.

### 핵심 정보

| 항목 | 값 |
|------|-----|
| Base URL | `https://open.poizon.com` |
| 기본 메서드 | POST (Bill/Bonded 일부 GET) |
| 인증 방식 | App Key + App Secret → MD5 서명 |
| 언어 코드 | `ko` |
| 타임존 | `Asia/Seoul` |

### 추가 패키지

```yaml
dependencies:
  dio: ^5.4.3                    # HTTP 클라이언트
  crypto: ^3.0.3                 # MD5 서명 생성
  flutter_secure_storage: ^9.0.0 # App Key/Secret 안전 저장
  retry: ^3.1.2                  # API 재시도 로직
```

### 프로젝트 구조 추가

```
lib/core/
├── api/
│   ├── poizon_client.dart       # Dio 인스턴스 + 서명 인터셉터
│   ├── poizon_signer.dart       # MD5 서명 생성 (Dart 구현)
│   └── endpoints/
│       ├── item_api.dart        # 상품 조회
│       ├── listing_api.dart     # 리스팅 관리
│       ├── order_api.dart       # 주문 관리
│       ├── bill_api.dart        # 정산
│       └── return_api.dart      # 반품
└── sync/
    └── poizon_sync_service.dart # POIZON API → 로컬 SQLite 동기화
```

### 데이터 흐름

```
[POIZON Open API]
       │  셀러 주문/상품/정산 데이터
       ▼
[Flutter 앱]
  ├── PoizonClient: API 호출 + MD5 서명 자동 처리
  ├── PoizonSyncService: 변경사항 감지 → 로컬 DB 업데이트
  └── 로컬 SQLite (Drift): 오프라인에서도 즉시 데이터 표시
       │
       ↓
[Google Drive appDataFolder]
       │  Windows ↔ Android 기기 간 동기화
```

### 로컬 캐시 TTL 전략

| 데이터 | 캐시 유효 시간 | 이유 |
|--------|-------------|------|
| 상품 정보 (SKU/SPU) | 24시간 | 변경 빈도 낮음 |
| 최저가 추천 | 5분 | 실시간 경쟁 가격 |
| 주문 목록 | 1분 | 신규 주문 즉시 반영 |
| 정산 내역 | 1시간 | 일별 정산 처리 |
| 재고 현황 | 10분 | 판매/반품 반영 |

### MVP 우선 구현 API

| 우선순위 | API | 용도 |
|---------|-----|------|
| 🔴 필수 | Query SKU by barcode / article number | 상품 검색 |
| 🔴 필수 | recommend-bid | 최저가 조회 |
| 🔴 필수 | submit-bid (Ship-to-verify) | 리스팅 등록 |
| 🔴 필수 | cancel-bid | 리스팅 취소 |
| 🔴 필수 | order list V2 | 주문 조회 |
| 🔴 필수 | Ship Order | 발송 처리 |
| 🟡 중요 | update-bid | 리스팅 수정 |
| 🟡 중요 | bill/reconciliation-list | 정산 내역 |
| 🟡 중요 | return APIs | 반품 처리 |
| 🟢 선택 | Smart Listing APIs | 자동 가격 최적화 |

> 📄 상세 API 레퍼런스: `docs/poizon-api/POIZON-API-REFERENCE.md`

### 보안 주의사항

- `App Key` / `App Secret`은 **절대 코드에 하드코딩 금지**
- `flutter_secure_storage`에 암호화 저장 (기기 키체인/키스토어 활용)
- `.env` 파일은 `.gitignore`에 반드시 추가

```dart
// ✅ 올바른 방법
final storage = FlutterSecureStorage();
await storage.write(key: 'poizon_app_key', value: appKey);
final key = await storage.read(key: 'poizon_app_key');

// ❌ 절대 금지
const appKey = 'your_actual_app_key_here';
```

---

## 13. 동기화 로직 구현 방향

### 단계별 구현 우선순위

**Phase 1 — 로컬 기능 완성**
- Drift DB 스키마 정의 및 CRUD 구현
- UI 완성 (Windows + Android 공통)
- CRDT 타임스탬프 적용

**Phase 2 — POIZON API 연동**
- App Key/Secret 입력 UI (최초 설정)
- PoizonClient + 서명 로직 구현
- 상품검색 → 리스팅 → 주문관리 순서로 연동

**Phase 3 — Google Drive 동기화**
- Google Sign-In 구현
- Drive appDataFolder 읽기/쓰기
- 수동 동기화 버튼 구현

**Phase 4 — 자동화**
- 앱 포그라운드 진입 시 POIZON 데이터 자동 갱신
- 백그라운드 Google Drive 동기화
- 충돌 UI (사용자 선택이 필요한 케이스)

---

## 14. 주요 참고 자료

| 주제 | 링크 |
|------|------|
| Flutter Windows 시작 | https://docs.flutter.dev/platform-integration/windows |
| Drift 공식 문서 | https://drift.simonbinder.eu |
| crdt 패키지 | https://pub.dev/packages/crdt |
| google_sign_in | https://pub.dev/packages/google_sign_in |
| googleapis | https://pub.dev/packages/googleapis |
| Riverpod | https://riverpod.dev |
| POIZON Open Platform | https://open.poizon.com |
| POIZON API 레퍼런스 | `docs/poizon-api/POIZON-API-REFERENCE.md` |

---

*최초 작성: 2026-03-21*
