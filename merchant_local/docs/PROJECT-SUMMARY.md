# merchant_local 프로젝트 작업 요약

> 작성일: 2026-03-21

---

## 프로젝트 목적

기존 웹앱(Vercel + Supabase)과는 **별개로**, 데이터를 외부 서버에 저장하지 않는 완전 로컬 전용 셀러 관리 앱 신규 개발.

- 모든 데이터는 사용자 기기(로컬 SQLite)에 저장
- 개발자 서버 없음 → 데이터 유출 위험 최소화
- Windows 데스크톱 + Android 단일 코드베이스 (Flutter)

---

## 확정된 기술 스택

| 역할 | 기술 |
|------|------|
| UI 프레임워크 | Flutter 3.x (Windows + Android) |
| 로컬 DB | Drift (SQLite ORM) |
| 기기 간 동기화 | Google Drive appDataFolder |
| 충돌 해결 | CRDT (crdt 패키지, HLC 타임스탬프) |
| 외부 API | POIZON Open API (셀러 데이터 연동) |
| 상태 관리 | Riverpod |
| HTTP 클라이언트 | Dio |
| API 서명 | MD5 (crypto 패키지, Dart 직접 구현) |
| 인증 정보 저장 | flutter_secure_storage (기기 암호화) |

---

## 데이터 흐름

```
[POIZON Open API]
       │  셀러 상품 / 주문 / 정산 데이터
       ▼
[Flutter 앱 — Windows / Android]
  ├── PoizonClient  : MD5 서명 → API 호출
  ├── 로컬 SQLite   : 모든 데이터 영구 저장 (오프라인 지원)
  └── CRDT HLC      : 기기 간 수정 충돌 자동 해결
       │
       ▼
[Google Drive appDataFolder]  ← 사용자 본인 계정, 개발자 접근 불가
       │
       ▼
[다른 기기 (Windows ↔ Android) 데이터 동기화]
```

---

## 개발 단계 (Phase)

| Phase | 내용 | 상태 |
|-------|------|------|
| Phase 1 | 로컬 기능 완성 — Drift DB + CRUD + UI | 🔧 진행 예정 |
| Phase 2 | POIZON API 연동 — 상품/주문/정산 동기화 | ⏳ 대기 |
| Phase 3 | Google Drive 동기화 — 기기 간 데이터 동기화 | ⏳ 대기 |
| Phase 4 | 자동화 — 백그라운드 갱신, 자동 동기화 | ⏳ 대기 |

---

## 생성된 프로젝트 구조

```
merchant_local/
├── _init_project.bat          ← Flutter 초기화 스크립트 (1회 실행)
├── pubspec.yaml               ← 전체 패키지 의존성
├── analysis_options.yaml      ← 린트 설정
├── .gitignore
│
├── docs/
│   ├── PROJECT-SUMMARY.md     ← 이 파일
│   ├── dev-setup-guide.md     ← 개발환경 구축 가이드 (전체)
│   └── poizon-api/
│       ├── POIZON-API-REFERENCE.md    ← 통합 레퍼런스 (Flutter 최적화)
│       ├── 01-overview-and-authentication.md
│       ├── 02-item-api.md
│       ├── 03-listing-inventory-api.md
│       ├── 04-consignment-order-fulfillment-api.md
│       ├── 05-bill-return-merchant-api.md
│       ├── 06-smart-listing-bonded-api.md
│       └── 07-signature-samples-and-integration.md
│
└── lib/
    ├── main.dart
    ├── app.dart                        ← 라우팅 (GoRouter)
    ├── core/
    │   ├── api/
    │   │   ├── poizon_signer.dart      ← MD5 서명 (Dart 구현)
    │   │   ├── poizon_client.dart      ← API 싱글턴 클라이언트
    │   │   └── endpoints/
    │   │       ├── item_api.dart       ← 상품 조회
    │   │       ├── listing_api.dart    ← 리스팅 관리
    │   │       └── order_api.dart      ← 주문 / 배송
    │   └── database/
    │       ├── app_database.dart       ← Drift DB 설정
    │       └── tables/
    │           ├── sku_table.dart
    │           ├── listing_table.dart
    │           ├── order_table.dart
    │           └── sync_meta_table.dart
    └── features/
        ├── home/home_screen.dart
        └── settings/settings_screen.dart  ← App Key 입력 UI
```

---

## 다음 단계: Flutter 환경 세팅

### 확인 순서

**1단계 — Flutter SDK 설치 여부 확인**
```
# PowerShell 또는 CMD에서 실행
flutter --version
```

**2단계 — 설치 안 된 경우**
1. https://docs.flutter.dev/get-started/install/windows 에서 다운로드
2. `C:\flutter` 에 압축 해제
3. 시스템 환경변수 PATH에 `C:\flutter\bin` 추가
4. Visual Studio Community 설치 (C++ 데스크톱 개발 워크로드)
5. Android Studio 설치 + SDK 설정

**3단계 — flutter doctor 통과 확인**
```
flutter doctor
```
아래 항목이 ✅ 되어야 Windows + Android 빌드 가능:
- Flutter SDK
- Android toolchain
- Visual Studio (Windows용)

**4단계 — 프로젝트 초기화**
```
# merchant_local 폴더에서 실행
_init_project.bat
```

**5단계 — 앱 실행**
```
flutter run -d windows
flutter run -d android
```

---

## POIZON API 핵심 정보

| 항목 | 값 |
|------|-----|
| Base URL | `https://open.poizon.com` |
| 인증 | App Key + App Secret → MD5 서명 |
| 언어 | `ko` / 타임존 `Asia/Seoul` |
| 상세 문서 | `docs/poizon-api/POIZON-API-REFERENCE.md` |

App Key / App Secret은 앱 실행 후 설정 화면에서 입력 → 기기 암호화 저장 (코드에 직접 입력 금지)

---

*정리: 2026-03-21*
