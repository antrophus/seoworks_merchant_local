# merchant_local — 프로젝트 기획서

> 버전: v1.0
> 작성일: 2026-03-21
> 상태: 기획 완료 / 개발 환경 세팅 대기

---

## 1. 프로젝트 배경 및 목적

### 배경
- 기존 웹 앱(Vercel + Supabase)은 셀러 데이터가 외부 서버에 저장됨
- 포이즌 셀러 운영 데이터(상품, 주문, 정산 등)의 보안 강화 필요
- Windows 데스크톱 + Android 모바일 양쪽에서 동일한 데이터 접근 필요

### 목적
- 데이터를 **사용자 기기에만 저장**하는 완전 온디바이스 앱 개발
- 개발자 서버 없이 사용자의 Google Drive를 통한 기기 간 동기화
- POIZON Open API를 통해 셀러 계정 데이터를 로컬에 동기화

---

## 2. 핵심 요구사항

### 기능 요구사항

| 분류 | 요구사항 | 우선순위 |
|------|---------|---------|
| 인증 | POIZON App Key / App Secret 로컬 암호화 저장 | 🔴 필수 |
| 상품 | 품번 / 바코드로 상품(SKU/SPU) 검색 | 🔴 필수 |
| 리스팅 | 현재 리스팅 목록 조회 | 🔴 필수 |
| 리스팅 | Ship-to-verify 리스팅 등록 / 수정 / 취소 | 🔴 필수 |
| 리스팅 | 최저가 추천 조회 | 🔴 필수 |
| 주문 | 신규 주문 조회 및 확인 | 🔴 필수 |
| 주문 | 발송 처리 (운송장 입력) | 🔴 필수 |
| 정산 | 정산 내역 조회 | 🟡 중요 |
| 반품 | 반품 주문 조회 및 처리 | 🟡 중요 |
| 동기화 | Google Drive를 통한 Windows ↔ Android 동기화 | 🟡 중요 |
| 동기화 | 앱 실행 시 POIZON 데이터 자동 갱신 | 🟡 중요 |
| 스마트 리스팅 | POIZON 자동 가격 최적화 리스팅 | 🟢 선택 |
| 보세 | 보세 창고 재고 / 주문 관리 | 🟢 선택 |

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
│                Domain Layer                      │
│         Use Cases / Repository Pattern            │
└──────────┬──────────────────┬───────────────────┘
           │                  │
┌──────────▼──────┐  ┌────────▼──────────────────┐
│  Remote Layer   │  │      Local Layer            │
│  POIZON API     │  │   Drift (SQLite)            │
│  Dio + MD5 서명 │  │   CRDT (HLC 타임스탬프)      │
└─────────────────┘  └────────┬──────────────────┘
                              │
                   ┌──────────▼──────────────────┐
                   │      Sync Layer              │
                   │  Google Drive appDataFolder  │
                   │  Windows ↔ Android 동기화     │
                   └─────────────────────────────┘
```

### 데이터 동기화 전략

```
[POIZON 서버]  ──(API)──▶  [로컬 SQLite]  ──(CRDT)──▶  [Google Drive]
                              ▲                               │
                              └───────────────────────────────┘
                                    다른 기기에서 pull
```

- POIZON API → 로컬 SQLite: 주기적 polling + 앱 포그라운드 진입 시 갱신
- 로컬 SQLite → Google Drive: 변경사항 감지 후 JSON 스냅샷 업로드
- CRDT HLC: 두 기기에서 동시 수정 시 자동 병합 (Last-Write-Wins)

---

## 4. 화면 구성 (Screen Flow)

```
앱 시작
  │
  ├── [최초 실행] ──▶ 설정 화면 (App Key 입력)
  │
  └── [기존 사용자] ──▶ 홈 화면 (대시보드)
                          │
                          ├── 📦 상품 탭
                          │     ├── 검색 (품번/바코드)
                          │     └── 상품 상세
                          │
                          ├── 📋 리스팅 탭
                          │     ├── 리스팅 목록
                          │     ├── 리스팅 등록
                          │     └── 최저가 추천
                          │
                          ├── 🛒 주문 탭
                          │     ├── 주문 목록 (신규/진행/완료)
                          │     ├── 주문 상세
                          │     └── 발송 처리
                          │
                          ├── 💰 정산 탭
                          │     └── 정산 내역 / 기간별 조회
                          │
                          └── ⚙️ 설정
                                ├── POIZON API 설정
                                ├── Google Drive 동기화
                                └── 앱 정보
```

---

## 5. 데이터베이스 스키마

### sku_items (상품 캐시)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | TEXT PK | DW skuId |
| spu_id | TEXT | SPU ID |
| global_sku_id | TEXT? | 글로벌 SKU ID |
| article_number | TEXT? | 품번 |
| brand_name | TEXT? | 브랜드명 |
| product_name | TEXT | 상품명 |
| size_info | TEXT? | 사이즈 정보 (JSON) |
| image_url | TEXT? | 대표 이미지 URL |
| hlc | TEXT | CRDT HLC 타임스탬프 |
| cached_at | DATETIME | 캐시 시각 |
| is_deleted | BOOL | 삭제 여부 |

### listings (리스팅)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| bid_id | TEXT PK | 포이즌 bidId |
| sku_id | TEXT | SKU ID |
| price | INTEGER | 가격 (최소단위) |
| quantity | INTEGER | 수량 |
| status | TEXT | active / cancelled / sold |
| listing_type | TEXT | ship_to_verify / consignment / pre_sale |
| country_code | TEXT | 발송 국가 |
| currency | TEXT | 통화 (기본 KRW) |
| hlc | TEXT | CRDT HLC |
| listed_at | DATETIME | 등록 시각 |
| updated_at | DATETIME | 수정 시각 |
| is_deleted | BOOL | 삭제 여부 |

### orders (주문)

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
| ordered_at | DATETIME | 주문 시각 |
| updated_at | DATETIME | 갱신 시각 |

### sync_meta (동기화 메타)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| key | TEXT PK | 키 (예: last_poizon_sync) |
| value | TEXT | 값 (타임스탬프 등) |
| updated_at | DATETIME | 갱신 시각 |

---

## 6. 개발 단계별 계획

### Phase 1 — 로컬 기반 완성 (MVP)

**목표:** 오프라인에서도 동작하는 로컬 데이터 기반 UI 완성

- [ ] Flutter 환경 세팅 (flutter doctor 통과)
- [ ] `_init_project.bat` 실행 → 패키지 설치 + 코드 생성
- [ ] Drift DB 스키마 마이그레이션 코드 작성
- [ ] 홈 화면 (탭 네비게이션) 구현
- [ ] 상품 검색 화면 (빈 상태 UI 포함)
- [ ] 리스팅 목록 화면
- [ ] 주문 목록 화면
- [ ] 기본 CRUD 테스트

**예상 소요:** 3~5일

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

**예상 소요:** 5~7일

### Phase 3 — Google Drive 동기화

**목표:** Windows ↔ Android 기기 간 데이터 동기화

- [ ] Google Sign-In 구현 (선택적 — 미로그인 시 로컬만 동작)
- [ ] Google Drive appDataFolder 연결
- [ ] 데이터 JSON 직렬화 (CRDT 메타 포함)
- [ ] Drive 업로드 / 다운로드
- [ ] CRDT 병합 로직 구현
- [ ] 수동 동기화 버튼
- [ ] 충돌 발생 시 UI 처리

**예상 소요:** 5~7일

### Phase 4 — 자동화 및 안정화

**목표:** 생산성 향상 및 UX 개선

- [ ] 앱 포그라운드 진입 시 POIZON 데이터 자동 갱신
- [ ] 백그라운드 Google Drive 자동 동기화
- [ ] 오류 처리 강화 (네트워크 오류, API 한도 초과)
- [ ] 로딩 상태 / 빈 상태 UI 정교화
- [ ] Windows / Android UI 반응형 레이아웃 최적화
- [ ] 앱 아이콘 / 스플래시 화면 적용

**예상 소요:** 3~5일

---

## 7. 주요 패키지 목록

| 패키지 | 버전 | 용도 |
|--------|------|------|
| drift | ^2.15.0 | SQLite ORM |
| sqlite3_flutter_libs | ^0.5.18 | SQLite 바이너리 |
| crdt | ^3.2.0 | CRDT 충돌 해결 |
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

---

## 8. 보안 정책

| 항목 | 정책 |
|------|------|
| App Key / App Secret | `flutter_secure_storage` 기기 암호화 저장, 코드 하드코딩 절대 금지 |
| 로컬 DB | 앱 샌드박스 내 저장, 일반 파일 탐색기 접근 불가 |
| Google Drive | 사용자 본인 계정 appDataFolder 사용 (개발자 접근 불가) |
| Git 커밋 | `.env`, `*.sqlite`, `key.properties`, `*.keystore` `.gitignore` 등록 |
| API 통신 | HTTPS 강제, 타임스탬프 기반 재사용 공격 방지 |

---

## 9. 다음 액션 아이템

집에서 할 작업 (순서대로):

1. `flutter --version` 확인
2. 미설치 시 Flutter SDK 설치 + `flutter doctor` 통과
3. `_init_project.bat` 실행 (패키지 설치 + 코드 생성)
4. `flutter run -d windows` 로 첫 빌드 확인
5. Phase 1 개발 시작

---

*기획 작성: 2026-03-21 (카페)*
*개발 시작: 귀가 후 작업용 PC*
