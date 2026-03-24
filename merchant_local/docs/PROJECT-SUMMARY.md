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
        │   ├── inventory_screen.dart           ← 재고 메인 화면 (검색/필터/바코드)
        │   ├── inventory_providers.dart        ← Providers + 상수 + SelectionNotifier
        │   ├── widgets/
        │   │   ├── item_tile.dart              ← 아이템 카드 + 불량/수선 칩
        │   │   ├── filter_chips.dart           ← 필터 칩 + 서브 탭
        │   │   ├── grouped_list_view.dart      ← 그룹뷰 + 배치리스트 + 정산 요약
        │   │   ├── batch_actions.dart          ← 필터별 일괄 처리 액션바
        │   │   └── barcode_widgets.dart        ← 바코드 스캔/결과 시트
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

## 2026-03-23 작업 내역 (셋째 날, 세션 2)

### 1. AI 인식 → 입고 폼 자동완성 ✅
- `scan_screen.dart`에서 보내는 쿼리 파라미터(brand/modelCode/modelName/sizeKr/category)를 `item_register_screen.dart`에서 수신
- 기존 상품 DB 매칭(modelCode) → 자동 선택, 없으면 신규 모드 전환 + 필드 자동 입력
- 브랜드명 → DB 브랜드 매칭, 사이즈차트 기반 EU 사이즈 자동완성

### 2. 입고 등록 버그 수정 5건 ✅
- **드롭다운 빈 목록 수정:** `initialValue` → `value`로 변경 (Flutter 3.41 호환)
- **모델코드 공백→하이픈:** LLM 응답 파싱 시 `AB1234 567` → `AB1234-567` 자동 변환
- **사이즈차트 활용:** 브랜드 선택 시 `size_charts` DB에서 KR→EU 자동 변환
- **수량 스테퍼:** 숫자 입력 → `- [1] +` 버튼 UI
- **매입처 필터+추가:** 온라인/오프라인 자동 필터 + 드롭다운 내 "새 매입처 추가"

### 3. 재고 목록 묶음 카드 뷰 ✅
- 상태별 그룹 카드: 발송중/검수중(발송일+송장), 리스팅(매입일), 정산완료(정산일+재무요약)
- 카드 UI: 우상단 날짜, 좌측 건수, 가운데 썸네일(최대5개+오버플로우), 하단 요약
- ExpansionTile로 탭하면 기존 아이템 리스트 펼침

### 4. 재고 필터 단순화 ✅
- 메인 5개: 전체 | 판매중 | 발송·검수 | 미등록 | 정산완료
- 서브 탭: 웹앱과 동일한 탭 형식 + 건수 표시 (예: `사무실재고 243개 | 리스팅 2개`)
- 더보기 토글: 판매완료 | 불량보류 | 수선중 | 반송중 | 기타
- 정렬 버튼 (↑↓): 날짜 오름/내림 토글

### 5. 성능/품질 개선 ✅
- **배치 로딩:** 플랫/그룹 뷰 모두 sale+purchase+product를 한번에 조회 (N+1 → 3쿼리)
- **검색 디바운스:** 300ms 디바운스로 타이핑 중 불필요 쿼리 차단
- **이미지 캐시:** `cached_network_image` 패키지 — 오프라인 캐시 지원
- **매입가 자동 포맷팅:** `123000` → `123,000` 실시간 (입고 등록/매입 등록)

### 6. 웹앱 플로우차트 완전 동기화 ✅
- **새 상태 2개:** `POIZON_STORAGE`(포이즌보관), `CANCEL_RETURNING`(취소반송)
- **검수 5분기:** 정상/하자판매/하자보관/하자반송 + **플랫폼취소(보관)** + **플랫폼취소(반송)**
- **POIZON_STORAGE 전이:** 보관판매 정산완료 / 반송 전환(CANCEL_RETURNING)
- **CANCEL_RETURNING 전이:** 수취 완료 → OFFICE_STOCK 재입고
- **Items 테이블:** `poizonStorageFrom` 컬럼 추가 (보관 시작일)
- **DB 스키마 v2→v3 마이그레이션:** 새 컬럼 + 기존 정산 데이터 settledAt 백필

### 7. 기타 수정 ✅
- **매입처 표시:** 아이템 카드/상세에서 결제수단 대신 매입처(소스) 이름 표시
- **정산일 자동 설정:** 검수통과 → SETTLED 전이 시 sale의 saleDate+settledAt 자동 기록
- **대시보드 카운트 갱신:** 탭 전환 시 `itemStatusCountsProvider` 자동 invalidate
- **대시보드 카드 재구성:** 판매중(LISTED+POIZON_STORAGE), 미등록(ORDER_PLACED+OFFICE_STOCK), 반송중(RETURNING+CANCEL_RETURNING) 통합
- **'기타' 카드:** 전체 필터 → 주문취소/공급처반품/폐기/샘플 복수 필터로 수정
- **adb install -r:** 앱 데이터 보존하며 업데이트 (API 키/DB 유지)

### 8. 필터 구성 (최종) ✅

| 메인 필터 | 상태 | 서브 탭 |
|----------|------|--------|
| 판매중 | LISTED + POIZON_STORAGE | 리스팅 \| 포이즌보관 |
| 발송·검수 | OUTGOING + IN_INSPECTION | 발송중 \| 검수중 |
| 미등록 | ORDER_PLACED + OFFICE_STOCK | 입고대기 \| 미등록재고 |
| 정산완료 | SETTLED + DEFECT_SETTLED | — |
| 반송중 | RETURNING + CANCEL_RETURNING | 하자반송 \| 취소반송 |

---

## 알려진 이슈 / 미완료 사항

### DropdownButtonFormField deprecation
- `value` 사용 중 (deprecated) — `initialValue`는 상태 반영이 안 되는 Flutter 버그. 동작에 문제 없음

### 상태 전이
- 웹앱 `system-flowchart.md`의 5분기 상태 머신과 동일하게 구현 완료
- `LISTED → SOLD → OUTGOING` 순서 (실판매가 입력 후 발송)
- 수선 완료 → OFFICE_STOCK으로 이동 (LISTED 직행 시 리스팅 다이얼로그 미연결)

### DB 스키마
- v3 마이그레이션: `poizon_storage_from` 컬럼 추가 + 기존 정산 데이터 `settledAt` 백필
- 에뮬레이터 데이터는 v3로 마이그레이션됨, Seeker도 앱 재시작 시 자동 마이그레이션

---

## 2026-03-24 작업 내역 (넷째 날)

### 1. inventory_screen.dart 파일 분리 리팩토링 ✅
- **2,498줄 단일 파일 → 7개 파일로 분리** (유지보수성 + 토큰 효율 개선)
  - `inventory_providers.dart` (~120줄) — Providers, 상수, 헬퍼, SelectionNotifier
  - `widgets/item_tile.dart` (~270줄) — ItemTile + 불량/수선 칩
  - `widgets/filter_chips.dart` (~95줄) — 필터 칩, 서브 탭
  - `widgets/grouped_list_view.dart` (~340줄) — 그룹뷰, 배치리스트, 정산 요약
  - `widgets/batch_actions.dart` (~530줄) — 일괄 처리 액션바 + 발송 시트
  - `widgets/barcode_widgets.dart` (~230줄) — 바코드 스캔/결과 시트
  - `inventory_screen.dart` (~290줄) — 메인 화면만
- `BatchDataLoader` 믹스인으로 데이터 로딩 코드 중복 제거
- 외부 파일 import 경로 수정 (dashboard_screen, home_screen)

### 2. 판매중 뷰 B안 전환 ✅
- **그리드 카드뷰 제거** — `_ListedGridView`, `_ListedGridCard` 삭제
- **전체 폭 GroupedListView로 전환** — 발송·검수 뷰와 동일한 UI 패턴
- 판매중은 **상품별 그룹핑** + `ItemTile`로 매입가/판매가/플랫폼 등 핵심 정보 표시
- 이미지 썸네일 Row 오버플로우 → 가로 스크롤 `ListView`로 수정

### 3. 판매중 카드 전용 레이아웃 ✅
- 이미지 1장 + **사이즈별 수량 Wrap 칩** (`240 ×2`, `250 ×3` 형태)
- 리스팅가합 → **매입가합**으로 변경
- 전체 수량 뱃지 표시 (`6개`)
- `ItemGroup.isListed` 플래그로 판매중 전용 타이틀 분기

### 4. 판매중 정렬 로직 ✅
- 기본(↓): 갯수 많은 순 → 동일 시 구매일 오래된 순
- 토글(↑): 갯수 적은 순 → 동일 시 구매일 최근 순
- `sortDate`를 productId 대신 그룹 내 가장 오래된 구매일로 설정

### 5. 선택 상태 Riverpod Provider 전환 ✅
- `setState` 로컬 state → `SelectionNotifier` (StateNotifierProvider) 전환
- `ref.watch(selectionProvider.select((ids) => ids.contains(item.id)))` — 아이템별 O(1) rebuild
- 선택 시 `GroupedListView` rebuild 없음, ExpansionTile 접힘 없음
- 12개 선택 관련 props 제거 (selectMode, selectedIds, onToggle, onLongPress × 3 위젯)
- 상단 헤더/하단 바 독립 `Consumer`로 분리

### 6. 필터 내 검색 지원 ✅
- `ItemDao.search()`에 `statuses` 옵션 파라미터 추가
- 필터 활성 상태에서 검색 시 해당 상태의 아이템만 검색
- 바코드 검색도 필터 인식 — 필터 상태 불일치 시 스낵바 안내

### 7. 필터별 하단 액션바 분기 ✅
- 복수 상태 필터에서도 포함된 상태 기준으로 버튼 표시
- **판매중:** 발송 + 리스팅취소 (+ 포이즌: 정산완료/반송전환)
- **발송·검수:** 검수도착 (+ 검수중: 검수통과/반려)
- **미등록:** 입고 + 주문취소 (+ 미등록재고: 리스팅등록/공급처반품/폐기)
- **검수 반려 바텀시트:** 검수통과 제외한 5개 반려 옵션 표시
- `_batchSimpleTransition()` 공통 메서드 + `_confirmDialog()` 추출로 코드 간소화

### 8. status_actions 보강 ✅
- `OFFICE_STOCK`에 공급처반품(SUPPLIER_RETURN) 액션 추가
- 샘플 전환 → '샘플/폐기'로 라벨 변경

---

## 다음 세션 작업 후보

1. **수선 완료 → 리스팅 플로우** — REPAIRING → LISTED 시 리스팅 다이얼로그 연결
2. **포이즌보관 90일 만료 알림** — 대시보드에 보관 만료 임박 아이템 경고
3. **대시보드 강화** — 긴급 알림 (발송 기한 초과, 불량 보류), 최근 활동 로그
4. **브랜드/매입처 마스터 관리 UI** (설정 화면)
5. **일괄 처리 고도화** — 리스팅등록/반려 시 다이얼로그 연동 (현재 단순 전이만)
6. **Phase 2: POIZON API 연동** — 상품 검색, 리스팅, 주문, 정산 동기화
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
- **에뮬레이터:** `Medium_Phone_API_36.1` (Android Studio AVD)
- **adb 경로 주의:** Git bash에서 `/sdcard` 경로 변환 이슈 → `MSYS_NO_PATHCONV=1` 필수
- **앱 업데이트:** `adb install -r` 사용 (데이터 보존), `flutter install`은 데이터 초기화됨
- **PowerShell 주의:** `&&` 안 됨 → `;` 또는 별도 명령어 사용
- **DB 스키마 버전:** v3

---

*정리: 2026-03-21*
*갱신: 2026-03-22 — 개발 환경 구축 + DB 재구성 + 데이터 임포트 + UI 구현*
*갱신: 2026-03-23 (세션1) — Phase 1 기능 대부분 완료 (상태전이/입고/매입판매/스캔/AI인식/Android빌드)*
*갱신: 2026-03-23 (세션2) — AI자동완성/필터단순화/묶음카드/배치로딩/웹앱5분기동기화/포이즌보관*
*갱신: 2026-03-24 — 파일분리리팩토링/판매중뷰B안/선택Provider전환/필터내검색/필터별액션바*
