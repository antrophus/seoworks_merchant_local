# merchant_local — 프로젝트 기획서

> 버전: v2.0
> 작성일: 2026-03-21
> 갱신일: 2026-03-22
> 상태: Phase 1 개발 중

---

## 1. 프로젝트 배경 및 목적

### 배경
- 기존 웹 앱(Vercel + Supabase)은 셀러 데이터가 외부 서버에 저장됨
- 포이즌 셀러 운영 데이터(상품, 주문, 정산 등)의 보안 강화 필요
- Windows 데스크톱 + Android 모바일 양쪽에서 동일한 데이터 접근 필요

### 목적
- 데이터를 **사용자 기기에만 저장**하는 완전 온디바이스 앱 개발
- 기존 웹앱의 **모든 기능을 로컬 앱으로 이식** (POIZON API 연동 포함)
- 개발자 서버 없이 사용자의 Google Drive를 통한 기기 간 동기화

### 웹앱 → 로컬앱 관계
- 웹앱(`merchant_manage`)의 기능을 **완전히 대체**하는 것이 최종 목표
- Supabase DB 스키마를 Drift(SQLite)로 1:1 이식
- 기존 데이터는 JSON 백업 → 로컬 DB 임포트로 마이그레이션

---

## 2. 핵심 요구사항

### 기능 요구사항 — 재고/매입/판매 관리 (웹앱 이식)

| 분류 | 요구사항 | 우선순위 |
|------|---------|---------|
| 재고 | 상품(Product) 마스터 관리 (브랜드, 모델코드, 카테고리) | 🔴 필수 |
| 재고 | 아이템(Item) 단위 재고 추적 (SKU, 사이즈, 바코드) | 🔴 필수 |
| 재고 | 16개 상태 관리 (ORDER_PLACED ~ DISPOSED) | 🔴 필수 |
| 재고 | 상태 변경 이력 자동 기록 (status_logs) | 🔴 필수 |
| 재고 | FIFO 재고 조회 | 🟡 중요 |
| 매입 | 매입 등록 (가격, 결제수단, 매입처) | 🔴 필수 |
| 매입 | 온라인(ORDER_PLACED) / 오프라인(OFFICE_STOCK) 구분 | 🔴 필수 |
| 매입 | 부가세 환급액 자동 계산 (법인카드 + 사업용) | 🟡 중요 |
| 판매 | 판매 등록 (플랫폼, 등록가, 판매가) | 🔴 필수 |
| 판매 | 2단계 가격: listed_price(등록가) vs sell_price(실판매가) | 🔴 필수 |
| 판매 | 플랫폼 수수료 자동 계산 (카테고리별 동적 규칙) | 🔴 필수 |
| 판매 | 정산금액 자동 계산 (판매가 - 수수료 + 조정금) | 🔴 필수 |
| 판매 | 판매 조정금 관리 (쿠폰, 패널티, 보관료) | 🟡 중요 |
| 판매 | 마진/수익률 계산 | 🟡 중요 |

### 기능 요구사항 — 배송/검수/수선

| 분류 | 요구사항 | 우선순위 |
|------|---------|---------|
| 배송 | 발송 추적 (운송장, 발송일, 순번 관리) | 🔴 필수 |
| 검수 | 4단계 검수 결과 처리 | 🔴 필수 |
|      | ① 정상 → SETTLED | |
|      | ② 경미 불량 + 할인 → DEFECT_FOR_SALE → DEFECT_SOLD | |
|      | ③ 경미 불량 + 보류 → DEFECT_HELD (재판매 대기) | |
|      | ④ 심각 불량 → RETURNING | |
| 검수 | 검수 반려 기록 (사유, 사진, 할인금액) | 🔴 필수 |
| 수선 | 수선 등록 (비용, 메모) | 🟡 중요 |
| 수선 | 수선 결과 (RELISTED / SUPPLIER_RETURN / DISPOSED / PERSONAL) | 🟡 중요 |
| 반품 | 공급처 반품 처리 | 🟡 중요 |
| 취소 | 주문 취소 처리 | 🟡 중요 |

### 기능 요구사항 — POIZON API 연동

| 분류 | 요구사항 | 우선순위 |
|------|---------|---------|
| 인증 | POIZON App Key / App Secret 로컬 암호화 저장 | 🔴 필수 |
| 상품 | 품번 / 바코드로 상품(SKU/SPU) 검색 | 🔴 필수 |
| 리스팅 | 리스팅 등록 / 수정 / 취소 | 🔴 필수 |
| 리스팅 | 최저가 추천 조회 | 🔴 필수 |
| 주문 | 주문 목록 조회 | 🔴 필수 |
| 주문 | 발송 처리 (운송장 입력) | 🔴 필수 |
| 정산 | 정산 내역 조회 | 🟡 중요 |
| 반품 | 반품 주문 조회 및 처리 | 🟡 중요 |

### 기능 요구사항 — 대시보드/분석

| 분류 | 요구사항 | 우선순위 |
|------|---------|---------|
| 대시보드 | 상태별 재고 현황 카드 | 🟡 중요 |
| 대시보드 | 브랜드별 분포 차트 | 🟢 선택 |
| 대시보드 | 최근 활동 로그 | 🟢 선택 |
| 대시보드 | 긴급 알림 (발송 기한 초과, 불량 보류) | 🟡 중요 |
| 분석 | 월별 매출 추이 | 🟢 선택 |
| 분석 | 플랫폼별 매출 비중 | 🟢 선택 |
| 분석 | 모델별 수익/손실 Top 10 | 🟢 선택 |

### 기능 요구사항 — 동기화/기타

| 분류 | 요구사항 | 우선순위 |
|------|---------|---------|
| 동기화 | Google Drive를 통한 Windows ↔ Android 동기화 | 🟡 중요 |
| 데이터 | Supabase 백업 JSON → 로컬 DB 초기 임포트 | 🔴 필수 |
| 설정 | 플랫폼 수수료 규칙 관리 | 🟡 중요 |
| 설정 | 브랜드/매입처 마스터 관리 | 🟡 중요 |
| 설정 | 사이즈 차트 관리 | 🟢 선택 |

### 비기능 요구사항
- 오프라인에서도 로컬 데이터로 앱 동작 (인터넷 연결 불필요)
- App Key / App Secret은 기기 키체인에 암호화 저장 (코드에 하드코딩 금지)
- Windows / Android 단일 코드베이스 유지
- Flutter doctor 기준 Windows + Android 빌드 모두 통과

---

## 3. 기술 아키텍처

### 레이어 구조

```
┌─────────────────────────────────────────────────┐
│                   UI Layer                       │
│         Flutter Widgets + GoRouter               │
│         Riverpod (상태 관리)                       │
└────────────────────┬────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────┐
│              Domain / Service Layer              │
│   비즈니스 로직 (정산 계산, 상태 전이, FIFO)         │
│   Repository Pattern                             │
└──────────┬──────────────────┬───────────────────┘
           │                  │
┌──────────▼──────┐  ┌────────▼──────────────────┐
│  Remote Layer   │  │      Local Layer            │
│  POIZON API     │  │   Drift (SQLite)            │
│  Dio + MD5 서명 │  │   18개 테이블 (웹앱 1:1 이식) │
└─────────────────┘  └────────┬──────────────────┘
                              │
                   ┌──────────▼──────────────────┐
                   │      Sync Layer              │
                   │  Google Drive appDataFolder  │
                   │  Windows ↔ Android 동기화     │
                   └─────────────────────────────┘
```

### 데이터 흐름

```
[Supabase 백업 JSON] ──(초기 임포트)──▶ [로컬 SQLite]
                                            ▲
[POIZON Open API] ──(실시간 연동)──────────┘  │
                                              │
                              ┌────────────────▼──────────────────┐
                              │  로컬 SQLite (Drift)               │
                              │  18개 테이블 + 비즈니스 로직         │
                              │  (정산 계산, 상태 전이, FIFO 등)    │
                              └────────────────┬──────────────────┘
                                               │
                              ┌─────────────────▼─────────────────┐
                              │  Google Drive appDataFolder        │
                              │  CRDT 기반 Windows ↔ Android 동기화 │
                              └───────────────────────────────────┘
```

---

## 4. 화면 구성 (Screen Flow)

```
앱 시작
  │
  ├── [최초 실행] ──▶ 설정 화면 (App Key 입력 + 데이터 임포트)
  │
  └── [기존 사용자] ──▶ 홈 화면 (대시보드)
                          │
                          ├── 📊 대시보드 탭
                          │     ├── 상태별 재고 현황 카드
                          │     ├── 긴급 알림 (발송 기한, 불량)
                          │     └── 최근 활동
                          │
                          ├── 📦 재고 탭
                          │     ├── 아이템 목록 (상태별 필터)
                          │     ├── 아이템 상세 (매입/판매/검수/발송 통합)
                          │     ├── 매입 등록
                          │     ├── 판매 등록
                          │     └── 상태 변경 (발송, 검수결과, 수선 등)
                          │
                          ├── 📋 리스팅 탭 (POIZON API)
                          │     ├── 리스팅 목록
                          │     ├── 리스팅 등록 (상품 검색 → 가격 추천 → 등록)
                          │     └── 최저가 추천
                          │
                          ├── 🛒 주문 탭 (POIZON API)
                          │     ├── 주문 목록 (신규/진행/완료)
                          │     ├── 주문 상세
                          │     └── 발송 처리
                          │
                          ├── 💰 정산 탭
                          │     ├── 정산 내역 / 기간별 조회
                          │     └── 수익/마진 분석
                          │
                          └── ⚙️ 설정
                                ├── POIZON API 설정
                                ├── 플랫폼 수수료 규칙
                                ├── 브랜드 / 매입처 관리
                                ├── Google Drive 동기화
                                ├── 데이터 임포트/백업
                                └── 앱 정보
```

---

## 5. 데이터베이스 스키마

> Supabase 운영 DB에서 1:1 이식 (상세: `docs/supabase-schema-for-drift.md`)

### 마스터 테이블

#### brands (브랜드)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | UUID |
| name | TEXT NOT NULL, UNIQUE | 브랜드명 |
| code | TEXT? UNIQUE | 브랜드 코드 |
| created_at | TEXT? | 생성일시 |

#### sources (매입처)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | UUID |
| name | TEXT NOT NULL, UNIQUE | 매입처명 |
| type | TEXT? | 유형 |
| url | TEXT? | URL |
| created_at | TEXT? | 생성일시 |

#### products (상품 모델)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | UUID |
| brand_id | TEXT? FK→brands | 브랜드 |
| model_code | TEXT NOT NULL, UNIQUE | 품번 |
| model_name | TEXT NOT NULL | 모델명 |
| gender | TEXT? | 성별 |
| category | TEXT? | 카테고리 (수수료 계산에 사용) |
| image_url | TEXT? | 대표 이미지 |
| poizon_spu_id | TEXT? UNIQUE | 포이즌 SPU ID |
| created_at | TEXT? | 생성일시 |

#### size_charts (사이즈 차트)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | UUID |
| brand | TEXT NOT NULL | 브랜드명 (TEXT, FK 아님) |
| target | TEXT NOT NULL | MEN / WOMEN / KIDS |
| kr | REAL NOT NULL | 한국 사이즈 |
| eu / us_m / us_w / us / uk / jp | TEXT? | 각국 사이즈 |
| created_at | TEXT? | 생성일시 |

### 핵심 테이블

#### items (아이템 — 재고 단위)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | UUID |
| product_id | TEXT NOT NULL FK→products | 상품 모델 |
| sku | TEXT NOT NULL, UNIQUE | SKU 코드 (예: ID6600-245-001) |
| size_kr | TEXT NOT NULL | 한국 사이즈 |
| size_eu / size_us / size_etc | TEXT? | 기타 사이즈 |
| barcode | TEXT? | 바코드 |
| tracking_number | TEXT? | 운송장 번호 |
| is_personal | INTEGER NOT NULL DEFAULT 0 | 개인용 여부 |
| current_status | TEXT NOT NULL DEFAULT 'OFFICE_STOCK' | 현재 상태 (16개 ENUM) |
| location | TEXT? | 보관 위치 |
| defect_note | TEXT? | 불량 메모 |
| note | TEXT? | 비고 |
| poizon_sku_id | TEXT? | 포이즌 SKU ID |
| created_at | TEXT? | 생성일시 |
| updated_at | TEXT? | 수정일시 |

**item_status ENUM 값 (16개):**
```
ORDER_PLACED, ORDER_CANCELLED, OFFICE_STOCK, OUTGOING, IN_INSPECTION,
LISTED, SOLD, SETTLED, RETURNING, DEFECT_FOR_SALE, DEFECT_SOLD,
DEFECT_SETTLED, SUPPLIER_RETURN, DISPOSED, SAMPLE, DEFECT_HELD, REPAIRING
```

#### purchases (매입 — items 1:1)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | UUID |
| item_id | TEXT NOT NULL, UNIQUE FK→items | 아이템 |
| purchase_date | TEXT? | 매입일 (YYYY-MM-DD) |
| purchase_price | INTEGER? | 매입가 (원) |
| payment_method | TEXT NOT NULL DEFAULT 'PERSONAL_CARD' | 결제수단 |
| source_id | TEXT? FK→sources | 매입처 |
| vat_refundable | REAL? | 부가세 환급액 |
| receipt_url | TEXT? | 영수증 URL |
| memo | TEXT? | 메모 |
| created_at | TEXT? | 생성일시 |

**payment_method ENUM:** `CORPORATE_CARD, PERSONAL_CARD, CASH, TRANSFER`

#### sales (판매 — items 1:1)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | UUID |
| item_id | TEXT NOT NULL, UNIQUE FK→items | 아이템 |
| sale_date | TEXT? | 판매일 |
| platform | TEXT NOT NULL | 판매 플랫폼 |
| platform_option | TEXT? | 플랫폼 옵션 |
| listed_price | INTEGER? | 등록가 |
| sell_price | INTEGER? | 실판매가 |
| platform_fee_rate | REAL? | 수수료율 |
| platform_fee | INTEGER? | 수수료 |
| settlement_amount | INTEGER? | 정산금 |
| adjustment_total | INTEGER NOT NULL DEFAULT 0 | 조정금 합계 |
| outgoing_date | TEXT? | 발송일 |
| shipment_deadline | TEXT? | 발송 기한 |
| tracking_number | TEXT? | 운송장 |
| settled_at | TEXT? | 정산일 |
| memo | TEXT? | 메모 |
| poizon_order_id | TEXT? UNIQUE | 포이즌 주문 ID |
| data_source | TEXT? DEFAULT 'manual' | 데이터 출처 |
| created_at | TEXT? | 생성일시 |

**sale_platform ENUM:** `KREAM, POIZON, SOLDOUT, DIRECT, OTHER`

### 부속 테이블

#### sale_adjustments (판매 조정금)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | UUID |
| sale_id | TEXT NOT NULL FK→sales (CASCADE) | 판매 |
| type | TEXT NOT NULL | COUPON / PENALTY / STORAGE_FEE / OTHER |
| amount | INTEGER NOT NULL | 금액 |
| memo | TEXT? | 메모 |
| created_at | TEXT? | 생성일시 |

#### status_logs (상태 변경 이력)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | UUID |
| item_id | TEXT NOT NULL FK→items | 아이템 |
| old_status | TEXT? | 이전 상태 |
| new_status | TEXT NOT NULL | 새 상태 |
| note | TEXT? | 비고 |
| changed_at | TEXT? | 변경일시 |

#### inspection_rejections (검수 반려)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | UUID |
| item_id | TEXT NOT NULL FK→items | 아이템 |
| return_seq | INTEGER NOT NULL | 반려 순번 (자동 생성) |
| rejected_at | TEXT NOT NULL | 반려일 |
| reason | TEXT? | 사유 |
| photo_urls | TEXT? | 사진 URL (JSON 배열) |
| platform | TEXT? | 플랫폼 |
| memo | TEXT? | 메모 |
| defect_type | TEXT? | DEFECT_SALE / DEFECT_HELD / DEFECT_RETURN |
| discount_amount | INTEGER? | 할인금액 |
| created_at | TEXT? | 생성일시 |

#### repairs (수선)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | UUID |
| item_id | TEXT NOT NULL FK→items | 아이템 |
| started_at | TEXT NOT NULL | 수선 시작일 |
| completed_at | TEXT? | 완료일 |
| repair_cost | INTEGER? | 수선 비용 |
| repair_note | TEXT? | 수선 메모 |
| outcome | TEXT? | RELISTED / SUPPLIER_RETURN / DISPOSED / PERSONAL |
| created_at | TEXT NOT NULL | 생성일시 |

#### shipments (배송)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | UUID |
| item_id | TEXT NOT NULL FK→items | 아이템 |
| seq | INTEGER NOT NULL | 배송 순번 (자동 생성) |
| tracking_number | TEXT NOT NULL | 운송장 번호 |
| outgoing_date | TEXT? | 발송일 |
| platform | TEXT? | 플랫폼 |
| memo | TEXT? | 메모 |
| created_at | TEXT? | 생성일시 |

#### supplier_returns (공급처 반품)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | UUID |
| item_id | TEXT NOT NULL, UNIQUE FK→items | 아이템 |
| returned_at | TEXT NOT NULL | 반품일 |
| reason | TEXT? | 사유 |
| memo | TEXT? | 메모 |
| created_at | TEXT? | 생성일시 |

#### order_cancellations (주문 취소)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | UUID |
| item_id | TEXT NOT NULL, UNIQUE FK→items | 아이템 |
| cancelled_at | TEXT NOT NULL | 취소일 |
| reason | TEXT? | 사유 |
| memo | TEXT? | 메모 |
| created_at | TEXT? | 생성일시 |

#### sample_usages (샘플 전환)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | UUID |
| item_id | TEXT NOT NULL, UNIQUE FK→items | 아이템 |
| purpose | TEXT NOT NULL | 용도 |
| used_at | TEXT? | 사용일 |
| memo | TEXT? | 메모 |
| created_at | TEXT? | 생성일시 |

### 설정/로그 테이블

#### platform_fee_rules (플랫폼 수수료 규칙)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | UUID |
| platform | TEXT NOT NULL | 플랫폼 |
| category | TEXT NOT NULL DEFAULT 'default' | 카테고리 |
| fee_rate | REAL NOT NULL | 수수료율 |
| min_fee | INTEGER NOT NULL DEFAULT 0 | 최소 수수료 |
| max_fee | INTEGER? | 최대 수수료 |
| note | TEXT? | 비고 |
| updated_at | TEXT? | 수정일시 |

#### poizon_sync_logs (포이즌 동기화 로그)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | UUID |
| sync_type | TEXT NOT NULL | orders / inspection / settlement 등 |
| window_start / window_end | TEXT? | 동기화 기간 |
| synced_at | TEXT? | 동기화 시각 |
| records_in / records_ok / records_skip | INTEGER? | 건수 |
| status | TEXT NOT NULL | success / partial / error |
| error_msg | TEXT? | 에러 메시지 |

#### sync_meta (동기화 메타 — 기존 유지)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| key | TEXT PK | 키 |
| value | TEXT | 값 |
| updated_at | TEXT | 갱신 시각 |

### POIZON API 캐시 테이블 (기존 유지)

#### poizon_sku_cache (포이즌 SKU 캐시)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | DW skuId |
| spu_id | TEXT | SPU ID |
| global_sku_id | TEXT? | 글로벌 SKU ID |
| article_number | TEXT? | 품번 |
| brand_name | TEXT? | 브랜드명 |
| product_name | TEXT | 상품명 |
| size_info | TEXT? | 사이즈 정보 (JSON) |
| image_url | TEXT? | 대표 이미지 |
| hlc | TEXT | CRDT HLC |
| cached_at | TEXT | 캐시 시각 |
| is_deleted | INTEGER DEFAULT 0 | 삭제 여부 |

#### poizon_listings (포이즌 리스팅 캐시)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| bid_id | TEXT PK | 포이즌 bidId |
| sku_id | TEXT | SKU ID |
| price | INTEGER | 가격 |
| quantity | INTEGER | 수량 |
| status | TEXT | active / cancelled / sold |
| listing_type | TEXT | ship_to_verify / consignment / pre_sale |
| country_code | TEXT | 발송 국가 |
| currency | TEXT | 통화 |
| hlc | TEXT | CRDT HLC |
| listed_at | TEXT | 등록 시각 |
| updated_at | TEXT | 수정 시각 |
| is_deleted | INTEGER DEFAULT 0 | 삭제 여부 |

#### poizon_orders (포이즌 주문 캐시)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| order_id | TEXT PK | 포이즌 주문 ID |
| sku_id | TEXT | SKU ID |
| status | TEXT | pending / confirmed / shipped / completed |
| sale_price | INTEGER | 판매가 |
| buyer_country | TEXT? | 구매자 국가 |
| tracking_no | TEXT? | 운송장 번호 |
| carrier_code | TEXT? | 운송사 코드 |
| qc_result | TEXT? | QC 결과 (JSON) |
| hlc | TEXT | CRDT HLC |
| ordered_at | TEXT | 주문 시각 |
| updated_at | TEXT | 갱신 시각 |

### 테이블 관계도

```
brands ──┐
         └──< products.brand_id
                  │
sources ──┐      │
          │      └──< items.product_id
          │                │
          │                ├──< purchases.item_id (1:1)
          │                │         └── purchases.source_id ──> sources
          │                │
          │                ├──< sales.item_id (1:1)
          │                │         └──< sale_adjustments.sale_id (CASCADE)
          │                │
          │                ├──< status_logs.item_id (N:1)
          │                ├──< inspection_rejections.item_id (N:1)
          │                ├──< repairs.item_id (N:1)
          │                ├──< shipments.item_id (N:1)
          │                ├──< supplier_returns.item_id (1:1)
          │                ├──< order_cancellations.item_id (1:1)
          │                └──< sample_usages.item_id (1:1)

platform_fee_rules (독립)
poizon_sync_logs (독립)
sync_meta (독립)
size_charts (독립)
poizon_sku_cache / poizon_listings / poizon_orders (POIZON API 캐시, 독립)
```

---

## 6. 비즈니스 로직 (Supabase 트리거 → Drift DAO 이식)

### 6-1. 정산금액 자동 계산 (calculate_sale_settlement)
```
IF sell_price IS NOT NULL:
  IF platform == 'POIZON':
    1. items → products 조인으로 category 조회
    2. platform_fee_rules에서 (platform='POIZON', category) 매칭
    3. 없으면 category='default' 폴백
    4. fee = CLAMP(sell_price × fee_rate, min_fee, max_fee)
    5. settlement_amount = sell_price - fee + adjustment_total
  IF platform IN ('DIRECT', 'OTHER'):
    fee = 0, settlement = sell_price + adjustment_total
  ELSE IF platform_fee_rate IS NOT NULL:
    fee = ROUND(sell_price × platform_fee_rate)
    settlement = sell_price - fee + adjustment_total
```

### 6-2. 조정금 합계 동기화 (sync_sale_adjustment_total)
```
sale_adjustments INSERT/UPDATE/DELETE 후:
  total = SUM(amount) FROM sale_adjustments WHERE sale_id = ?
  UPDATE sales SET adjustment_total = total
  → settlement_amount 재계산
```

### 6-3. 부가세 환급액 계산 (calculate_vat_refundable)
```
IF is_personal == FALSE AND payment_method == 'CORPORATE_CARD':
  vat_refundable = ROUND(purchase_price / 11.0, 2)
ELSE:
  vat_refundable = 0
```

### 6-4. 상태 변경 + 로그 자동 기록 (update_item_status)
```
Transaction:
  1. old_status = SELECT current_status FROM items WHERE id = ?
  2. UPDATE items SET current_status = new_status, updated_at = now()
  3. INSERT INTO status_logs (item_id, old_status, new_status, note)
```

### 6-5. 순번 자동 생성
- inspection_rejections.return_seq: MAX(return_seq) + 1 per item_id
- shipments.seq: MAX(seq) + 1 per item_id

### 6-6. FIFO 재고 조회 (get_fifo_item)
```
SELECT i.* FROM items i
JOIN products p ON i.product_id = p.id
WHERE p.model_code = ? AND i.current_status = 'OFFICE_STOCK'
  AND i.is_personal = FALSE
  AND (? IS NULL OR i.size_kr = ?)
ORDER BY i.created_at ASC LIMIT 1
```

---

## 7. 개발 단계별 계획

### Phase 1 — 로컬 DB + 재고/매입/판매 UI (MVP)

**목표:** 웹앱의 핵심 데이터를 로컬에 저장하고 관리하는 UI 완성

- [x] Flutter 환경 세팅 (flutter doctor 통과)
- [x] 패키지 설치 + 코드 생성
- [ ] Drift DB 스키마 전면 재구성 (18개 테이블 + 인덱스)
- [ ] 비즈니스 로직 DAO 구현 (정산 계산, 상태 전이, FIFO 등)
- [ ] Supabase 백업 JSON → 로컬 DB 임포트 기능
- [ ] 홈 화면 (대시보드 — 상태별 재고 현황)
- [ ] 재고 탭 (아이템 목록, 상태 필터, 검색)
- [ ] 아이템 상세 화면 (매입/판매/검수/발송 통합 뷰)
- [ ] 매입 등록/수정 화면
- [ ] 판매 등록/수정 화면 (수수료 자동 계산)
- [ ] 상태 변경 처리 (발송, 검수결과, 수선 등)
- [ ] 기본 CRUD 테스트

### Phase 2 — POIZON API 연동

**목표:** 실제 셀러 데이터를 앱에서 확인 및 관리

- [ ] 설정 화면에서 App Key / App Secret 입력 및 저장
- [ ] PoizonClient 연결 테스트
- [ ] 상품 검색 연동 (품번 / 바코드)
- [ ] 리스팅 목록 조회 연동
- [ ] 최저가 추천 조회
- [ ] 리스팅 등록 / 수정 / 취소
- [ ] 주문 목록 조회
- [ ] 발송 처리 (운송장 입력)
- [ ] 정산 내역 조회
- [ ] 로컬 캐시 TTL 전략 적용
- [ ] POIZON 주문 → 로컬 sales 테이블 자동 매칭

### Phase 3 — Google Drive 동기화

**목표:** Windows ↔ Android 기기 간 데이터 동기화

- [ ] Google Sign-In 구현 (선택적 — 미로그인 시 로컬만 동작)
- [ ] Google Drive appDataFolder 연결
- [ ] 데이터 JSON 직렬화 (CRDT 메타 포함)
- [ ] Drive 업로드 / 다운로드
- [ ] CRDT 병합 로직 구현
- [ ] 수동 동기화 버튼
- [ ] 충돌 발생 시 UI 처리

### Phase 4 — 자동화, 분석, 안정화

**목표:** 생산성 향상, 분석 기능, UX 개선

- [ ] 앱 포그라운드 진입 시 POIZON 데이터 자동 갱신
- [ ] 백그라운드 Google Drive 자동 동기화
- [ ] 대시보드 차트 (브랜드 분포, 매출 추이)
- [ ] 수익/마진 분석 (모델별 Top 10)
- [ ] 플랫폼별 매출 비중 분석
- [ ] 오류 처리 강화
- [ ] Windows / Android 반응형 레이아웃 최적화
- [ ] 앱 아이콘 / 스플래시 화면

---

## 8. 주요 패키지 목록

| 패키지 | 버전 | 용도 |
|--------|------|------|
| drift | ^2.15.0 | SQLite ORM |
| sqlite3_flutter_libs | ^0.5.18 | SQLite 바이너리 |
| crdt | ^5.1.3 | CRDT 충돌 해결 |
| google_sign_in | ^6.2.1 | Google 인증 |
| googleapis | ^12.0.0 | Drive API |
| dio | ^5.4.3 | HTTP 클라이언트 |
| crypto | ^3.0.3 | MD5 서명 |
| flutter_secure_storage | ^9.0.0 | 키체인 저장 |
| retry | ^3.1.2 | API 재시도 |
| flutter_riverpod | ^2.5.1 | 상태 관리 |
| freezed_annotation | ^2.4.1 | 불변 모델 |
| go_router | ^13.2.0 | 라우팅 |
| uuid | ^4.3.3 | 고유 ID 생성 |
| logger | ^2.3.0 | 로깅 |
| intl | ^0.19.0 | 날짜/숫자 포맷 |

---

## 9. 보안 정책

| 항목 | 정책 |
|------|------|
| App Key / App Secret | `flutter_secure_storage` 기기 암호화 저장, 코드 하드코딩 절대 금지 |
| 로컬 DB | 앱 샌드박스 내 저장, 일반 파일 탐색기 접근 불가 |
| Google Drive | 사용자 본인 계정 appDataFolder 사용 (개발자 접근 불가) |
| Git 커밋 | `.env`, `*.sqlite`, `key.properties`, `*.keystore` `.gitignore` 등록 |
| API 통신 | HTTPS 강제, 타임스탬프 기반 재사용 공격 방지 |

---

## 10. 데이터 마이그레이션 (Supabase → 로컬)

### 백업 JSON 위치
```
d:\dev\2026\my_project\merchant_manage\backups\2026-03-15_12-26-16\
├── brands.json, sources.json, products.json, size_charts.json
├── items.json, purchases.json, sales.json, sale_adjustments.json
├── status_logs.json, inspection_rejections.json, repairs.json
├── shipments.json, supplier_returns.json, order_cancellations.json
└── sample_usages.json
```

### 임포트 순서 (FK 의존성 준수)
1. brands → 2. sources → 3. products → 4. size_charts
5. platform_fee_rules (시드) → 6. items → 7. purchases → 8. sales
9. sale_adjustments → 10. status_logs → 11~16. 나머지

### 주의사항
- `is_personal`: JSON `true/false` → SQLite `1/0` 변환
- 백업에 없는 컬럼 (`poizon_sku_id`, `poizon_order_id`, `data_source`)은 NULL 처리
- 최신 데이터 필요 시 웹앱에서 백업 재실행 후 사용

---

*기획 작성: 2026-03-21 (카페)*
*v2.0 업데이트: 2026-03-22 — 웹앱 전체 기능 + Supabase 스키마 반영*
