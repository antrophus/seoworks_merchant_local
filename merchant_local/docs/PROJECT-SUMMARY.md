# merchant_local 프로젝트 작업 요약

> 작성일: 2026-03-21
> 갱신일: 2026-03-23

---

## 프로젝트 목적

기존 웹앱(Vercel + Supabase)의 **모든 기능을 로컬 앱으로 이식**하여, 데이터를 외부 서버에 저장하지 않는 완전 로컬 전용 셀러 관리 앱 개발.

- 모든 데이터는 사용자 기기(로컬 SQLite)에 저장
- 개발자 서버 없음 → 데이터 유출 위험 최소화
- Windows 데스크톱 + Android 단일 코드베이스 (Flutter)
- Supabase DB 스키마를 Drift(SQLite)로 1:1 이식

---

## 확정된 기술 스택

| 역할 | 기술 |
|------|------|
| UI 프레임워크 | Flutter 3.41.5 (Windows + Android) |
| 로컬 DB | Drift (SQLite ORM) — 21개 테이블 |
| 기기 간 동기화 | Google Drive appDataFolder |
| 충돌 해결 | CRDT (crdt 패키지, HLC 타임스탬프) |
| 외부 API | POIZON Open API (셀러 데이터 연동) |
| 상태 관리 | Riverpod |
| HTTP 클라이언트 | Dio |
| API 서명 | MD5 (crypto 패키지, Dart 직접 구현) |
| 인증 정보 저장 | flutter_secure_storage (기기 암호화) |
| 라우팅 | GoRouter |
| 바코드 스캔 | mobile_scanner (Android/iOS only) |
| 이미지 처리 | image_picker + image (리사이즈) |
| AI 상품 인식 | LLM 캐스케이딩 (Claude → Grok → DeepSeek) |

---

## 개발 단계 (Phase)

| Phase | 내용 | 상태 |
|-------|------|------|
| Phase 1 | 로컬 DB + 재고/매입/판매 UI + 데이터 임포트 | ✅ 거의 완료 |
| Phase 2 | POIZON API 연동 — 상품/주문/정산 동기화 | ⏳ 대기 |
| Phase 3 | Google Drive 동기화 — 기기 간 데이터 동기화 | ⏳ 대기 |
| Phase 4 | 자동화, 분석, 안정화 | ⏳ 대기 |

---

## 2026-03-22 작업 내역 (첫째 날)

### 개발 환경 구축 완료
- Flutter 3.41.5 (stable) 설치 확인
- Visual Studio Community 2026 설치 (C++ 데스크톱 개발)
- Android Studio Panda 2 설치 + SDK 34 + Build-Tools + Emulator
- `flutter doctor` — No issues found!
- Windows 앱 첫 빌드 + 실행 확인

### DB 스키마 전면 재구성 (4개 → 21개 테이블)

기존 POIZON API 캐시 전용 테이블 4개에서, 웹앱(Supabase)의 전체 스키마를 이식하여 21개 테이블로 확장.

**마스터 (4개):** Brands, Sources, Products, SizeCharts
**핵심 (4개):** Items, Purchases, Sales, SaleAdjustments
**부속 (7개):** StatusLogs, InspectionRejections, Repairs, Shipments, SupplierReturns, OrderCancellations, SampleUsages
**설정/로그 (3개):** PlatformFeeRules, PoizonSyncLogs, SyncMeta
**POIZON 캐시 (3개):** PoizonSkuCache, PoizonListings, PoizonOrders

### DAO 8개 구현 (비즈니스 로직 포함)

| DAO | 핵심 기능 |
|-----|----------|
| ItemDao | 상태 변경 + 로그 자동 기록, FIFO 재고 조회, 대시보드 통계, **검색(search)**, **상품별 전체아이템 조회(getAllByProductId)** |
| PurchaseDao | 부가세 환급액 자동 계산 (법인카드 + 사업용) |
| SaleDao | 플랫폼 수수료 자동 계산 (카테고리별), 정산금 계산, 조정금 동기화 |
| MasterDao | 브랜드/매입처/상품/사이즈차트/수수료규칙 CRUD |
| SubRecordDao | 검수반려/수선/배송(순번 자동 생성), 반품/취소/샘플, 동기화 로그 |
| SkuDao | POIZON SKU 캐시 CRUD + 검색 |
| ListingDao | POIZON 리스팅 캐시 CRUD + 상태 필터 |
| OrderDao | POIZON 주문 캐시 CRUD + 상태 필터 |

### Supabase 백업 데이터 임포트 기능

- `DataImportService` 구현 — JSON 파일 15개 테이블 파싱 + DB 삽입
- FK 의존성 순서 준수 (brands → items → sales 순)
- 타입 변환 자동 처리 (bool→int, 누락 컬럼 null)
- 설정 화면에서 폴더 선택 → 임포트 실행 → 결과 표시
- **실제 임포트 성공: 6,497건** (brands 198, sources 39, products 371, size_charts 372, items 1197, purchases 1196, sales 1195, sale_adjustments 1, status_logs 993, inspection_rejections 11, repairs 3, shipments 921)

### UI 화면 구현 (초기)

- 홈 화면 4탭: 대시보드 | 재고 | 리스팅 | 주문
- 대시보드: 요약 카드 + 12개 상태별 재고 현황 그리드
- 재고 목록: 상태 필터 칩 + 카드형 아이템 리스트
- 아이템 상세: 기본정보/매입/판매/배송/검수반려/수선/상태이력 통합 뷰

### 기타
- DB 스키마 v1→v2 마이그레이션 처리
- 플랫폼 수수료 규칙 시드 데이터 9건 자동 삽입
- PLANNING.md v2.0 업데이트

---

## 2026-03-23 작업 내역 (둘째 날)

### 1. 대시보드 → 재고 네비게이션 ✅
- 대시보드 상태별 카드 클릭 → `inventoryFilterProvider` 설정 + 재고 탭(인덱스 1)으로 전환
- `_StatusCard`에 `onTap` 콜백 + `InkWell` 추가 (count > 0일 때만 활성)
- **파일:** `dashboard_screen.dart`

### 2. 매입/판매 등록·수정 화면 ✅
- **매입 폼** (`purchase_form_screen.dart`): 매입가, 결제수단(4종), 매입처(DB 드롭다운), 매입일, 메모. 법인카드 시 부가세 환급 자동 계산
- **판매 폼** (`sale_form_screen.dart`): 플랫폼(5종), 등록가, 판매가, 수수료율(KREAM/SOLDOUT), 판매일, 메모. POIZON은 카테고리별 수수료 자동 계산
- 아이템 상세 화면에 매입/판매 **등록 버튼** (데이터 없을 때) + **수정 아이콘** (있을 때) 추가
- `_SectionCard`에 `trailing` 파라미터 추가
- **라우트:** `/item/:id/purchase`, `/item/:id/sale` (수정: `?edit=id`)

### 3. 입고 등록 화면 ✅
- **`item_register_screen.dart`** — 완전 신규 상품도 등록 가능
- **입고 유형:** 오프라인 입고(OFFICE_STOCK) / 온라인 주문(ORDER_PLACED)
- **상품 선택 모드 전환:** "기존 상품 검색" ↔ "신규 상품 등록" 토글
  - 기존: 모델명/모델코드 타이핑 → 드롭다운 자동완성 → 선택
  - 신규: **브랜드 드롭다운** + 모델코드 + 모델명 + 카테고리 입력 → Product 레코드 자동 생성
- **사이즈별 수량 일괄 입력:** 동적 행 추가/삭제, 각 행마다 KR사이즈 + EU사이즈(선택) + 수량
  - 같은 모델 여러 족 한번에 등록 (예: 270 2족 + 275 1족 → 3건 Item+Purchase 생성)
- SKU 자동 생성: `모델코드-사이즈-순번` (기존 DB 조회 후 순번 증가)
- 매입 정보 동시 입력 (매입가, 결제수단, 매입처, 매입일)
- 총 N족 카운트 실시간 표시
- **라우트:** `/register`
- **진입점:** 재고 탭 FAB(+) 버튼

### 4. 상태 전이 시스템 ✅
- **`status_actions.dart`** — 상태 전이 규칙 + 다이얼로그 모음 (단일 파일)
- 모든 상태에서 가능한 액션을 `statusActions` 맵으로 정의

#### 올바른 비즈니스 흐름 (기획서 기반):
```
입고 → 사무실재고 → 리스팅(등록가) → 판매확정(실판매가) → 발송(운송장) → 검수 → 정산
```

#### 상태별 가능 액션:
| 현재 상태 | 가능한 액션 |
|-----------|------------|
| 주문완료 | 입고(사무실 도착), 주문 취소 |
| **사무실재고** | **리스팅 등록** (플랫폼+등록가), 샘플 전환 |
| **리스팅** | **판매 확정** (실판매가 입력), 리스팅 취소 |
| **판매완료** | **발송** (운송장 입력) |
| 발송중 | 검수 도착 |
| 검수중 | 검수 통과(정산), 불량판매, 불량보류, 반송 |
| 불량판매 | 불량 판매 완료, 수선 시작 |
| 불량판매완료 | 불량 정산 완료 |
| 불량보류 | 재판매(복귀), 수선, 공급처 반품, 폐기 |
| 반송중 | 사무실 도착(재입고), 수선 |
| 수선중 | 완료→재등록/공급처반품/폐기/개인전환 |

#### 전이별 다이얼로그 구현:
- **리스팅 등록** (`OFFICE_STOCK → LISTED`): 플랫폼 선택 + 등록가 → Sale 레코드 생성
- **판매 확정** (`LISTED → SOLD`): 기존 리스팅 정보 표시 + 실판매가 입력 → Sale 업데이트 (수수료+정산금 자동 계산)
- **발송 처리** (`SOLD → OUTGOING`): 운송장 번호 + 플랫폼 → Shipment 레코드 생성
- **검수 반려**: 사유 + 불량유형 + 할인금액 → InspectionRejection 생성
- **수선 시작/완료**: 메모/비용/결과 → Repair 생성/완료
- **주문 취소**: 사유 → OrderCancellation 생성
- **공급처 반품**: 사유 → SupplierReturn 생성

#### 진입점:
- **아이템 상세 화면:** 우하단 "상태 변경" FAB → 바텀시트 → 다이얼로그
- **재고 목록:** 각 아이템 우측 상태변경 아이콘(⇄) + **길게 누르기(long press)**

### 5. 재고 목록 강화 ✅
- **수선/반송 아이템에 사유·이미지 표시:** `_DefectInfoChip` (검수반려 정보 + 사진 썸네일), `_RepairInfoChip` (수선 정보)
- 불량 관련 상태 아이템에 자동 표시 (REPAIRING, RETURNING, DEFECT_FOR_SALE, DEFECT_HELD 등)
- **검색바 추가:** SKU, 모델코드, 모델명, 바코드 실시간 검색
  - 검색 중 상태 필터 칩 숨김
  - ItemDao에 `search()` 메서드 추가 (items JOIN products, LIKE 검색)
- **바코드 카메라 버튼** (검색바 우측):
  - Android: `MobileScannerController` 바텀시트 카메라
  - Windows: 바코드 직접 입력 다이얼로그
  - 바코드 발견 시 → 사이즈별 재고/구매/판매 이력 바텀시트
  - 미등록 시 → "없는 상품" 안내 → 입고 등록 연결

### 6. 바코드 / AI 이미지 인식 ✅
- **홈 화면 5탭 변경:** 대시보드 | 재고 | **스캔** | 리스팅 | 주문

#### 바코드 스캔 탭 (`scan_screen.dart`):
- Android: `mobile_scanner` 후면 카메라 실시간 스캔, 토치/카메라 전환
- Windows: 카메라 대신 바코드 직접 입력 텍스트 필드 (플랫폼 분기)
- 스캔 → DB 바코드 조회 → 있으면 아이템 정보 카드 + 상세 이동, 없으면 입고 등록 연결

#### AI 이미지 인식 탭:
- 카메라 촬영 or 갤러리 선택 → 이미지 리사이즈 (max 1024px, JPEG 85%)
- AI 분석 버튼 → LLM 캐스케이딩 호출 → 결과 카드 (브랜드/모델코드/모델명/사이즈/바코드/카테고리/성별)
- 바코드 발견 시 자동 DB 조회
- "이 정보로 입고 등록" → 쿼리 파라미터로 결과 전달

#### LLM 캐스케이딩 라우터 (`llm_router.dart`):
- **Claude (Anthropic)** → **Grok (xAI)** → **DeepSeek** 순서로 시도
- API 키가 있는 프로바이더만 시도, 실패 시 다음으로 폴백
- Claude: Anthropic Messages API / Grok·DeepSeek: OpenAI-compatible API
- 프롬프트로 brand, model_code, model_name, size_kr, barcode, category, gender JSON 추출
- API 키는 `flutter_secure_storage`에 암호화 저장

### 7. 설정 화면 확장 ✅
- **LLM API 키 설정 섹션 추가:** Claude/Grok/DeepSeek 각각 키 입력·저장·삭제
- `_LlmKeyField` 위젯 (프로바이더별 독립 상태, 비밀번호 토글, 저장 버튼)
- **데이터 임포트 플랫폼 분기:**
  - Windows: 폴더 선택 → `importFromBackupDir()` (기존)
  - Android: **파일 다중 선택** → `importFromFiles()` (신규) — SAF 권한 문제 해결

### 8. Android 빌드 환경 ✅
- `flutter create --platforms=android .` 실행 → `android/` 폴더 생성
- `AndroidManifest.xml` 권한 추가: CAMERA, INTERNET, READ/WRITE_EXTERNAL_STORAGE, MANAGE_EXTERNAL_STORAGE
- `android:requestLegacyExternalStorage="true"` 설정
- 실기기(Galaxy) USB 디버깅 연결 확인
- **adb로 JSON 백업 파일 전송:** `adb push ... /sdcard/Download/db_backup`
- 데이터 임포트 Android 권한 이슈 → 파일 선택 방식(`pickFiles`)으로 해결

---

## 프로젝트 구조 (현재)

```
merchant_local/
├── pubspec.yaml
├── android/                            ← 신규 생성 (Android 빌드)
├── windows/
├── docs/
│   ├── PROJECT-SUMMARY.md              ← 이 파일
│   ├── PLANNING.md                     ← 기획서 v2.0
│   ├── dev-setup-guide.md              ← 개발환경 가이드
│   ├── supabase-schema-for-drift.md    ← Supabase→Drift 이식 가이드
│   └── poizon-api/                     ← POIZON API 레퍼런스 (7개 파일)
│
└── lib/
    ├── main.dart
    ├── app.dart                        ← GoRouter 라우팅 (7개 라우트)
    ├── core/
    │   ├── providers.dart              ← Riverpod Providers (DB + API + 재고)
    │   ├── api/
    │   │   ├── poizon_client.dart
    │   │   ├── poizon_signer.dart
    │   │   └── endpoints/              ← item/listing/order API (스캐폴딩)
    │   ├── database/
    │   │   ├── app_database.dart       ← 21개 테이블 + 8개 DAO 등록
    │   │   ├── tables/                 ← 17개 테이블 정의 파일
    │   │   └── daos/                   ← 8개 DAO (비즈니스 로직 포함)
    │   └── services/
    │       ├── data_import_service.dart ← Supabase JSON 임포트 (폴더/파일 양방식)
    │       └── llm_router.dart         ← LLM 캐스케이딩 (Claude→Grok→DeepSeek)
    └── features/
        ├── dashboard/dashboard_screen.dart     ← 상태별 재고 현황 + 탭 전환
        ├── home/home_screen.dart               ← 5탭 네비게이션
        ├── inventory/
        │   ├── inventory_screen.dart           ← 재고 목록 + 필터 + 검색바 + 바코드
        │   ├── item_detail_screen.dart         ← 아이템 상세 (통합 뷰 + 상태변경 FAB)
        │   ├── item_register_screen.dart       ← 입고 등록 (신규상품 + 다건 사이즈)
        │   ├── purchase_form_screen.dart       ← 매입 등록/수정
        │   ├── sale_form_screen.dart           ← 판매 등록/수정
        │   └── status_actions.dart             ← 상태 전이 규칙 + 다이얼로그 모음
        ├── scan/scan_screen.dart               ← 바코드 스캔 + AI 이미지 인식
        ├── listings/listings_screen.dart       ← POIZON 리스팅 (스캐폴딩)
        ├── orders/orders_screen.dart           ← POIZON 주문 (스캐폴딩)
        ├── products/products_screen.dart       ← POIZON SKU 검색 (스캐폴딩)
        └── settings/settings_screen.dart       ← API 설정 + 데이터 임포트 + LLM 키
```

### GoRouter 라우트 목록 (`app.dart`)

| 라우트 | 화면 | 비고 |
|--------|------|------|
| `/` | HomeScreen (5탭) | 대시보드/재고/스캔/리스팅/주문 |
| `/settings` | SettingsScreen | API키 + 임포트 + LLM키 |
| `/item/:id` | ItemDetailScreen | 아이템 상세 + 상태변경 FAB |
| `/item/:id/purchase` | PurchaseFormScreen | 매입 등록/수정 (`?edit=id`) |
| `/item/:id/sale` | SaleFormScreen | 판매 등록/수정 (`?edit=id`) |
| `/register` | ItemRegisterScreen | 입고 등록 (신규상품 + 다건) |

---

## 알려진 이슈 / 미완료 사항

### 빌드 관련
- `build_runner` 재실행 필요할 수 있음: `dart run build_runner build --delete-conflicting-outputs`
- Android 임포트: **파일 다중 선택** 방식으로 변경됨 (SAF 폴더 접근 권한 이슈 해결)
- 아직 Android에서 실제 임포트 테스트 미완료 (파일 선택 방식 구현 후 테스트 필요)

### DropdownButtonFormField 경고
- `value` → `initialValue` 로 변경했으나, 일부 화면에서 상태 변경 시 드롭다운 값 반영이 안 될 수 있음 (Flutter 3.41.5 deprecation)

### 입고 등록 화면 (`item_register_screen.dart`)
- AI 이미지 인식 결과를 쿼리 파라미터로 전달하는 로직 구현됨, 하지만 **수신 측에서 파라미터 파싱하여 폼에 자동완성하는 코드는 아직 미구현**

### 상태 전이 참고사항
- 웹앱 `system-flowchart.md`의 상태 머신과 동일하게 구현함
- `LISTED → OUTGOING` 이 아닌 `LISTED → SOLD → OUTGOING` 순서 (실판매가 입력 후 발송)
- 수선 완료 → LISTED로 갈 때 리스팅 다이얼로그가 연결되지 않음 (현재 OFFICE_STOCK으로 이동)

---

## 다음 세션 작업 후보

1. **Android 임포트 테스트** — 파일 선택 방식이 실제로 동작하는지 확인
2. **입고 등록 쿼리파라미터 수신** — AI 인식 결과 → 입고 폼 자동완성
3. **수선 완료 → 리스팅 플로우** — REPAIRING → LISTED 시 리스팅 다이얼로그 연결
4. **Phase 2: POIZON API 연동** — 상품 검색, 리스팅, 주문, 정산 동기화
5. **대시보드 강화** — 긴급 알림 (발송 기한 초과, 불량 보류), 최근 활동 로그
6. **브랜드/매입처 마스터 관리 UI** (설정 화면)
7. **Phase 3: Google Drive 동기화**

---

## 환경 정보 (다음 세션 참고)

- **Flutter 경로:** `E:\Users\antro\AppData\Local\Programs\flutter`
- **Android SDK 경로:** `E:\Users\antro\AppData\Local\Programs\Android\SDK`
- **프로젝트 경로:** `D:\dev\2026\my_project\seoworks_merchant_local\merchant_local`
- **웹앱 플로우차트:** `D:\dev\2026\my_project\merchant_manage\docs\system-flowchart.md`
- **백업 JSON 경로:** `D:\dev\2026\my_project\merchant_manage\backups\2026-03-21_17-04-07`
- **DB 파일 위치:** `{문서폴더}/merchant_local/app_data.sqlite`
- **실기기:** Galaxy (USB 디버깅 연결, `flutter devices`에서 "Seeker"로 표시)
- **PowerShell 주의:** `&&` 안 됨 → `;` 또는 별도 명령어 사용

---

*정리: 2026-03-21*
*갱신: 2026-03-22 — 개발 환경 구축 + DB 재구성 + 데이터 임포트 + UI 구현*
*갱신: 2026-03-23 — Phase 1 기능 대부분 완료 (상태전이/입고/매입판매/스캔/AI인식/Android빌드)*
