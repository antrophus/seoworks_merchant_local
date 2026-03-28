# 웹앱 → 로컬앱 기능 이식 검토 및 작업계획서

> 작성일: 2026-03-24
> 최종 업데이트: 2026-03-25
> 비교 대상: merchant_manage (웹앱, Next.js + Supabase) vs merchant_local (로컬앱, Flutter + Drift)

---

## 1. 기능별 구현 현황 비교

### 범례
- ✅ 구현 완료
- 🔶 부분 구현 (구조는 있으나 기능 미완성)
- ❌ 미구현
- ➖ 해당 없음 (로컬앱 아키텍처 특성상 불필요)

---

### 1.1 인증 (Authentication)

| 웹앱 ID | 기능 | 웹앱 | 로컬앱 | 비고 |
|---------|------|------|--------|------|
| AUTH-01~04 | 이메일/비밀번호 로그인, 미들웨어, RLS | ✅ | ➖ | 로컬앱은 단일 사용자 온디바이스 → 인증 불필요 |

---

### 1.2 대시보드 (Dashboard)

| 웹앱 ID | 기능 | 웹앱 | 로컬앱 | 비고 |
|---------|------|------|--------|------|
| DASH-01 | KPI 카드 (상태별 아이템 수) | ✅ | ✅ | Phase 2-A 완료: 6개 KPI 카드 (미등록/발송·검수/판매중/하자/정산/반송·수선) |
| DASH-02 | 자산 개요 (총 구매원가, 등록가, 예상이익) | ✅ | ✅ | Phase 2-A 완료: 자산 개요 섹션 (구매원가/등록가/정산금/예상이익) |
| DASH-03 | 브랜드 차트 (Top 6 Bar 차트) | ✅ | ❌ | 미구현 (Phase 2-B) |
| DASH-04 | 캘린더 위젯 | ✅ | ❌ | 미구현 (Phase 2-C) |
| DASH-05 | 최근 활동 타임라인 (8건) | ✅ | ✅ | Phase 2-A 완료: 최근 상태변경 8건 타임라인 |
| DASH-06 | 긴급 알림 (발송기한 경고) | ✅ | ❌ | 미구현 (Phase 2-B) |
| DASH-07 | 카드 → 페이지 링크 | ✅ | ✅ | KPI 카드 + 상태 그리드 탭 → 인벤토리 필터 이동 |

---

### 1.3 구매 관리 (Purchase Management)

| 웹앱 ID | 기능 | 웹앱 | 로컬앱 | 비고 |
|---------|------|------|--------|------|
| PUR-01 | 구매 내역 목록 | ✅ | ✅ | Phase 2-B 완료: purchases_screen.dart |
| PUR-02 | 단일 구매 등록 | ✅ | ✅ | item_register_screen + purchase_form_screen |
| PUR-03 | 배치 구매 등록 (여러 사이즈×수량) | ✅ | ✅ | 기구현: 다중 사이즈×수량 행 + 루프 생성 |
| PUR-04 | 브랜드 Combobox (검색/선택) | ✅ | ✅ | item_register_screen에 구현 |
| PUR-05 | 품번 Combobox (브랜드별 필터, 신규 인라인 등록) | ✅ | ✅ | 구현됨 |
| PUR-06 | SizePicker (size_charts 매칭, 남/여/키즈 탭) | ✅ | ✅ | Phase 2-A 완료: size_charts 기반 탭형 바텀시트 + 자동 매핑 |
| PUR-07 | 의류 카테고리 분기 (비신발류 수동입력) | ✅ | ❌ | 카테고리별 사이즈 입력 분기 없음 |
| PUR-08 | 채널 토글 (온라인/오프라인) | ✅ | ✅ | 구현됨 |
| PUR-09 | 온라인 URL 입력 (receipt_url) | ✅ | ❌ | receipt_url 필드 미사용 |
| PUR-10 | SKU 자동 생성 | ✅ | ✅ | 구현됨 |
| PUR-11 | VAT 자동 계산 | ✅ | ✅ | 구현됨 |
| PUR-12 | AI 자동완성 (스캔 → 구매등록 연결) | ✅ | ✅ | scan_screen → item_register_screen 연결 |

---

### 1.4 재고 관리 (Inventory Management)

#### 1.4.1 재고 목록

| 웹앱 ID | 기능 | 웹앱 | 로컬앱 | 비고 |
|---------|------|------|--------|------|
| INV-01 | 상태별 필터링 (20개 상태 + 그룹 뱃지) | ✅ | ✅ | filter_chips + inventory_providers |
| INV-02 | 검색 (SKU, 모델명, 품번) | ✅ | ✅ | 구현됨 |
| INV-03 | 정렬 (구매일/구매가/등록가/판매가) | ✅ | ✅ | Phase 2-B 완료: 등록일/구매가/등록가/판매가 정렬 |
| INV-04 | 개인/샘플 필터 | ✅ | ✅ | Phase 2-B+ 완료: 개인/사업용 토글 버튼 (inventoryPersonalFilterProvider) |
| INV-05 | 카드 리스트 뷰 (무한 스크롤) | ✅ | ✅ | item_tile + ListView |
| INV-06 | 체크박스 선택 (전체 선택/해제) | ✅ | ✅ | selectionProvider |
| INV-07 | 확장 패널 (이미지, 구매/판매 정보) | ✅ | ✅ | Sprint 3 완료: 확장 토글 버튼 + AnimatedSize 패널 (큰 이미지, SKU, 매입일, VAT, 등록가, 발송일, 수익 계산) |
| INV-08 | 판매중 그룹 탭 (사무실/포이즌 창고 분리) | ✅ | ✅ | SubFilterTabs로 구현됨 (리스팅/포이즌보관 탭, 카운트 표시) |
| INV-09 | 재고 그룹 탭 (위치별) | ✅ | 🔶 | 미등록 subLabels (입고대기/미등록재고)로 부분 구현. 실제 위치 기반 분류는 미구현 |
| INV-10 | 발송 그룹 탭 (발송일+운송장별) | ✅ | ✅ | SubFilterTabs로 구현됨 (발송중/검수중 탭) + GroupedListView 발송일+송장 그룹핑 |
| INV-11 | 카메라 조회 (바코드로 아이템 검색) | ✅ | ✅ | barcode_widgets + scan_screen |
| INV-12 | Sticky 헤더 | ✅ | ✅ | Sprint 3 완료: SliverPersistentHeader(pinned) + CustomScrollView. 전체뷰↔압축뷰 전환, 접기/펼치기 지원 |

#### 1.4.2 벌크 액션

| 웹앱 ID | 기능 | 웹앱 | 로컬앱 | 비고 |
|---------|------|------|--------|------|
| BULK-01 | 판매 등록 (OFFICE_STOCK → LISTED) | ✅ | ✅ | batch_actions + status_actions |
| BULK-02 | 등록 취소 (LISTED → OFFICE_STOCK) | ✅ | ✅ | 구현됨 |
| BULK-03 | 발송 처리 (LISTED → OUTGOING) | ✅ | ✅ | 구현됨 |
| BULK-04 | 검수 진행 (OUTGOING → IN_INSPECTION) | ✅ | ✅ | 구현됨 |
| BULK-05 | 정산 완료 (IN_INSPECTION → SETTLED) | ✅ | ✅ | 구현됨 |
| BULK-06 | 하자 반려 (IN_INSPECTION → DEFECT 분기) | ✅ | ✅ | 기구현: _InspectionSheet (사유/메모/할인금액/사진/defectType) |
| BULK-07 | 플랫폼 취소 (IN_INSPECTION → POIZON_STORAGE/CANCEL_RETURNING) | ✅ | ✅ | 기구현: _InspectionSheet에서 PLATFORM_CANCEL 처리 |
| BULK-08 | 수선 시작 (RETURNING → REPAIRING) | ✅ | ✅ | 구현됨 |
| BULK-09 | 구매처 반품 (OFFICE_STOCK → SUPPLIER_RETURN) | ✅ | ✅ | 구현됨 |
| BULK-10 | 재입고 (CANCEL_RETURNING → OFFICE_STOCK) | ✅ | ✅ | 구현됨 |

#### 1.4.3 아이템 상세

| 웹앱 ID | 기능 | 웹앱 | 로컬앱 | 비고 |
|---------|------|------|--------|------|
| DET-01 | 구매 정보 편집 | ✅ | ✅ | purchase_form_screen |
| DET-02 | 판매 정보 편집 | ✅ | ✅ | sale_form_screen |
| DET-03 | 사이즈 수정 | ✅ | ✅ | item_detail_screen |
| DET-04 | 바코드 수정 | ✅ | ✅ | 구현됨 |
| DET-05 | 상태 이력 타임라인 | ✅ | ✅ | item_detail_screen |
| DET-06 | 반려 이력 + 사진 갤러리 | ✅ | 🔶 | 반려 이력은 표시되나 사진 갤러리 미구현 |
| DET-07 | 정산 조정 CRUD | ✅ | ✅ | sale_form_screen에 adjustment 관리 |
| DET-08 | 상태 되돌리기 | ✅ | ✅ | revertLastStatusChange 구현 |
| DET-09 | 아이템 삭제 (OFFICE_STOCK만) | ✅ | ✅ | 구현됨 |
| DET-10 | 발송 이력 | ✅ | ✅ | shipments 표시 |
| DET-11 | 수선 이력 | ✅ | ✅ | repairs 표시 |

---

### 1.5 판매 관리 (Sales Management)

| 웹앱 ID | 기능 | 웹앱 | 로컬앱 | 비고 |
|---------|------|------|--------|------|
| SALE-01 | 판매 내역 목록 | ✅ | ✅ | Phase 2-A 완료: 판매 탭 + 목록 (SKU/가격/수수료/정산 표시) |
| SALE-02 | 날짜 필터 (시작일/종료일, 프리셋) | ✅ | ✅ | Phase 2-A 완료: DatePicker + 이번달/지난달 프리셋 |
| SALE-03 | 플랫폼 필터 | ✅ | ✅ | Phase 2-A 완료: POIZON/KREAM/SOLDOUT/DIRECT/OTHER 필터칩 |
| SALE-04 | 개인/하자 필터 | ✅ | ✅ | Phase 2-B 완료 |
| SALE-05 | 요약 통계 (총 판매/정산/이익/마진율) | ✅ | ✅ | Phase 2-A 완료: 4개 통계 카드 |
| SALE-06 | CSV 내보내기 | ✅ | ✅ | Phase 2-B 완료: data_export_service.dart |
| SALE-07 | 상세 컬럼 (모델, 가격, 수수료, 마진) | ✅ | ✅ | Phase 2-A 완료: 카드형 목록에 상세 표시 |

---

### 1.6 수수료 자동 계산

| 웹앱 ID | 기능 | 웹앱 | 로컬앱 | 비고 |
|---------|------|------|--------|------|
| FEE-01 | 포이즌 자동 계산 (CLAMP) | ✅ | ✅ | sale_form_screen에서 계산 |
| FEE-02 | 카테고리별 수수료 | ✅ | ✅ | platform_fee_rules 테이블 참조 |
| FEE-03 | 동적 규칙 조회 | ✅ | ✅ | 구현됨 |
| FEE-04 | KREAM/SOLDOUT 수수료 | ✅ | ✅ | 직접 입력 |
| FEE-05 | 직거래 수수료 (0%) | ✅ | ✅ | 구현됨 |
| FEE-06 | 정산 자동 계산 | ✅ | ✅ | 앱 레벨에서 계산 (DB 트리거 대신) |
| FEE-07 | 조정 항목 자동 반영 | ✅ | ✅ | 구현됨 |
| FEE-08 | 수수료 규칙 CRUD | ✅ | ✅ | settings_screen |

---

### 1.7 검수 5분기 플로우

| 웹앱 ID | 기능 | 웹앱 | 로컬앱 | 비고 |
|---------|------|------|--------|------|
| INS-01 | 정상 통과 → SETTLED | ✅ | ✅ | 구현됨 |
| INS-02 | 경미 하자 (구매자 수락) → DEFECT_FOR_SALE | ✅ | ✅ | 상태 전이 가능 |
| INS-03 | 경미 하자 (구매자 거부) → DEFECT_HELD | ✅ | ✅ | 상태 전이 가능 |
| INS-04 | 중대 하자 → RETURNING | ✅ | ✅ | 상태 전이 가능 |
| INS-05 | 플랫폼 취소 → POIZON_STORAGE | ✅ | ✅ | 상태 전이 가능 |
| INS-06 | 플랫폼 취소 → CANCEL_RETURNING | ✅ | ✅ | 상태 전이 가능 |

> 상태 전이 자체는 모두 동작하나, **검수 반려 시 사유/사진/할인금액 입력 전용 다이얼로그**가 없음

---

### 1.8 수선 관리

| 웹앱 ID | 기능 | 웹앱 | 로컬앱 | 비고 |
|---------|------|------|--------|------|
| REP-01~07 | 수선 시작/완료/비용/노트 | ✅ | ✅ | status_actions + sub_record_dao |

---

### 1.9 바코드 / AI 이미지 인식

| 웹앱 ID | 기능 | 웹앱 | 로컬앱 | 비고 |
|---------|------|------|--------|------|
| SCAN-01~11 | 바코드/AI 인식 전체 | ✅ | ✅ | scan_screen에 전체 구현 |

---

### 1.10 분석 대시보드 (Analytics)

| 웹앱 ID | 기능 | 웹앱 | 로컬앱 | 비고 |
|---------|------|------|--------|------|
| ANA-01 | 요약 카드 (총 판매, 정산, 이익, 마진율) | ✅ | ✅ | Phase 2-B 완료: analytics_screen.dart |
| ANA-02 | 월별 트렌드 차트 (Area) | ✅ | ✅ | Phase 2-B 완료: fl_chart LineChart |
| ANA-03 | 플랫폼 분포 (Pie 차트) | ✅ | ✅ | Phase 2-B 완료: fl_chart PieChart |
| ANA-04 | Top 10 수익 모델 | ✅ | ✅ | Phase 2-B 완료 |
| ANA-05 | Top 10 손실 모델 | ✅ | ✅ | Phase 2-B 완료 |
| ANA-06 | 연도 필터 | ✅ | ✅ | Phase 2-B 완료 |
| ANA-07 | 브랜드별 매출 차트 (Bar) | ✅ | ✅ | Phase 2-B 완료 |
| ANA-08 | 브랜드 드릴다운 (아코디언) | ✅ | ✅ | Phase 2-B 완료 |
| ANA-09 | 기간 필터 (브랜드) | ✅ | ✅ | Phase 2-B 완료 |

---

### 1.11 하자 관리 (Exception Management)

| 웹앱 ID | 기능 | 웹앱 | 로컬앱 | 비고 |
|---------|------|------|--------|------|
| EXC-01 | 현재 하자 탭 | ✅ | ✅ | Phase 2-B 완료: exceptions_screen.dart |
| EXC-02 | 반려 이력 탭 | ✅ | ✅ | Phase 2-B 완료 |
| EXC-03 | 플랫폼/상태 필터 | ✅ | ✅ | Phase 2-B 완료 |
| EXC-04 | 사진 갤러리 | ✅ | ✅ | Phase 2-B 완료 |
| EXC-05 | 반려 상세 | ✅ | ✅ | Phase 2-B 완료 |

---

### 1.12 물류 추적 (Logistics)

| 웹앱 ID | 기능 | 웹앱 | 로컬앱 | 비고 |
|---------|------|------|--------|------|
| LOG-01 | 발송 이력 목록 | ✅ | ✅ | Phase 2-B 완료: logistics_screen.dart |
| LOG-02 | 택배사별 통계 | ✅ | ✅ | Phase 2-B 완료 |
| LOG-03 | 다중 발송 지원 | ✅ | ✅ | shipments 테이블 seq 필드 |
| LOG-04 | 운송장/발송일 표시 | ✅ | ✅ | 아이템 상세에서 표시 |

---

### 1.13 캘린더 (Calendar)

| 웹앱 ID | 기능 | 웹앱 | 로컬앱 | 비고 |
|---------|------|------|--------|------|
| CAL-01 | 월 뷰 | ✅ | ❌ | 미구현 |
| CAL-02 | 이벤트 인디케이터 | ✅ | ❌ | 미구현 |
| CAL-03 | 일별 상세 | ✅ | ❌ | 미구현 |

---

### 1.14 설정 (Settings)

| 웹앱 ID | 기능 | 웹앱 | 로컬앱 | 비고 |
|---------|------|------|--------|------|
| SET-01 | 연결 상태 표시 | ✅ | ✅ | POIZON API 설정 상태 표시 |
| SET-02~05 | 수수료 규칙 CRUD | ✅ | ✅ | 구현됨 |

---

### 1.15 POIZON API 동기화

| 웹앱 ID | 기능 | 웹앱 | 로컬앱 | 비고 |
|---------|------|------|--------|------|
| POI-01~03 | 주문/정산/반송 동기화 | 🔧 | 🔶 | 로컬앱: API 클라이언트 + 캐시 구조 구현, 실동기화 미연결 |
| POI-04 | 자동 동기화 (Cron) | 🔧 | ❌ | 로컬앱에서는 백그라운드 타이머/워크매니저로 대체 필요 |
| POI-05 | 수동 동기화 | 🔧 | 🔶 | listings/orders 탭에서 새로고침 가능 |
| POI-06 | DB 스키마 | ✅ | ✅ | Drift 테이블 구현 완료 |

---

### 1.16 로컬앱 전용 기능

| 기능 | 로컬앱 | 비고 |
|------|--------|------|
| Google Drive 동기화 | ❌ | SyncMeta 테이블 준비됨, CRDT HLC 지원, 실제 동기화 미구현 |
| 데이터 백업/내보내기 | ✅ | Phase 2-B 완료: JSON 전체/판매 CSV/재고 CSV 내보내기 (설정 화면) |
| 오프라인 동작 | ✅ | 로컬 SQLite 기반 완전 오프라인 |

---

## 2. 미구현 기능 요약 (우선순위별)

### 🔴 핵심 (Must-Have) — 웹앱 핵심 기능 중 로컬앱에 없는 것

| # | 기능 | 관련 ID | 예상 복잡도 |
|---|------|---------|------------|
| 1 | 판매 내역 페이지 (목록 + 필터 + 통계 + CSV) | SALE-01~07 | 높음 |
| 2 | 배치 구매 등록 (여러 사이즈×수량 일괄) | PUR-03 | 중간 |
| 3 | 검수 반려 입력 다이얼로그 (사유/사진/할인금액) | BULK-06, DET-06 | 중간 |
| 4 | 대시보드 강화 (KPI 6카드 + 자산개요) | DASH-01~02 | 중간 |
| 5 | SizePicker 고도화 (size_charts 탭형) | PUR-06~07 | 중간 |

### 🟡 중요 (Should-Have) — UX 향상에 필요

| # | 기능 | 관련 ID | 예상 복잡도 |
|---|------|---------|------------|
| 6 | 분석 대시보드 (차트 + 트렌드 + Top10) | ANA-01~09 | 높음 |
| 7 | 하자 관리 전용 페이지 | EXC-01~05 | 중간 |
| 8 | 물류 추적 전용 페이지 | LOG-01~02 | 낮음 |
| 9 | 구매 내역 전용 페이지 | PUR-01 | 낮음 |
| 10 | 인벤토리 정렬 확장 (구매가/등록가/판매가) | INV-03 | 낮음 |
| 11 | 인벤토리 그룹 탭 (판매중/재고/발송별) | INV-08~10 | 중간 |
| 12 | 개인/샘플 필터 | INV-04 | 낮음 |
| 13 | 인벤토리 확장 패널 (이미지 + 세부정보) | INV-07 | 중간 |
| 14 | 대시보드 나머지 (브랜드 차트, 최근 활동, 긴급 알림) | DASH-03~06 | 중간 |
| 15 | 데이터 내보내기 (JSON/CSV) | SALE-06 | 낮음 |
| 16 | Google Drive 동기화 | 로컬전용 | 높음 |

### 🟢 선택 (Nice-to-Have) — 있으면 좋은 기능

| # | 기능 | 관련 ID | 예상 복잡도 |
|---|------|---------|------------|
| 17 | 캘린더 뷰 (월별 이벤트) | CAL-01~03 | 중간 |
| 18 | Sticky 헤더 | INV-12 | 낮음 |
| 19 | 온라인 URL 입력 (receipt_url) | PUR-09 | 낮음 |
| 20 | 플랫폼 취소 세부 옵션 다이얼로그 | BULK-07 | 낮음 |
| 21 | 반려 사진 갤러리 | DET-06, EXC-04 | 중간 |
| 22 | POIZON 자동 동기화 (백그라운드) | POI-04 | 중간 |

---

## 3. 작업 계획 (Phase별)

### Phase 2-A: 핵심 기능 이식 (Must-Have)

> 목표: 웹앱의 핵심 비즈니스 기능을 로컬앱에 완전히 이식

#### Task 2A-1: 판매 내역 페이지 신규 개발
- **파일**: `lib/features/sales/sales_screen.dart` (신규)
- **파일**: `lib/features/sales/sales_providers.dart` (신규)
- **DAO 수정**: `sale_dao.dart`에 필터/집계 쿼리 추가
- **하위 작업**:
  1. SaleDAO에 날짜/플랫폼/상태 필터 쿼리 추가
  2. SaleDAO에 요약 통계 쿼리 (총 판매/정산/이익/마진율)
  3. SalesScreen 목록 UI (DataTable or ListView)
  4. 날짜 필터 (DateRangePicker + 프리셋 버튼)
  5. 플랫폼/개인/하자 필터 칩
  6. 요약 통계 카드 4개
  7. CSV 내보내기 (share_plus or file_picker로 저장)
  8. HomeScreen 네비게이션에 Sales 탭 추가
- **의존성**: sale_dao.dart, app.dart (라우트)

#### Task 2A-2: 배치 구매 등록
- **파일**: `lib/features/inventory/item_register_screen.dart` (수정)
- **하위 작업**:
  1. 배치 모드 토글 UI 추가
  2. 사이즈×수량 다중 행 입력 위젯
  3. PurchaseDAO에 배치 INSERT 트랜잭션 추가
  4. SKU 배치 자동 생성 (seq 증가)

#### Task 2A-3: 검수 반려 입력 다이얼로그
- **파일**: `lib/features/inventory/widgets/rejection_dialog.dart` (신규)
- **파일**: `lib/features/inventory/status_actions.dart` (수정)
- **하위 작업**:
  1. RejectionDialog 위젯 (defect_type 선택, 사유 입력, 할인금액, 사진 첨부)
  2. 사진 촬영/선택 → 로컬 저장 (path_provider)
  3. SubRecordDAO에 rejection + photos 저장 로직 추가
  4. 벌크 반려 시 다이얼로그 연동
  5. 아이템 상세 반려 이력에 사진 갤러리 추가

#### Task 2A-4: 대시보드 강화
- **파일**: `lib/features/dashboard/dashboard_screen.dart` (수정)
- **파일**: `lib/features/dashboard/dashboard_providers.dart` (신규)
- **하위 작업**:
  1. DashboardDAO 또는 기존 DAO에 집계 쿼리 추가
     - 상태 그룹별 카운트 (미등록/발송·검수/판매중/하자/정산/보관)
     - 자산 개요 (총 구매원가, 등록가 합계, 예상 이익)
  2. KPI 카드 6개 교체 (기존 3개 → 6개)
  3. 자산 개요 섹션 추가

#### Task 2A-5: SizePicker 고도화
- **파일**: `lib/features/inventory/widgets/size_picker.dart` (신규)
- **하위 작업**:
  1. size_charts 테이블에서 브랜드별 사이즈 조회
  2. 남/여/키즈 탭 UI
  3. 사이즈 행 클릭 → KR/EU/US 자동 매핑
  4. 의류 카테고리일 때 자유 입력 모드 전환
  5. item_register_screen에 기존 사이즈 입력 교체

---

### Phase 2-B: 중요 기능 이식 (Should-Have)

#### Task 2B-1: 분석 대시보드
- **파일**: `lib/features/analytics/analytics_screen.dart` (신규)
- **파일**: `lib/features/analytics/analytics_providers.dart` (신규)
- **패키지 추가**: `fl_chart` (Flutter 차트 라이브러리)
- **하위 작업**:
  1. 요약 카드 (총 판매, 정산, 이익, 마진율)
  2. 월별 트렌드 차트 (LineChart)
  3. 플랫폼 분포 (PieChart)
  4. Top 10 수익/손실 모델 (BarChart)
  5. 연도/기간 필터
  6. 브랜드별 매출 차트 + 드릴다운
  7. HomeScreen 또는 라우트에 분석 탭 추가

#### Task 2B-2: 하자 관리 페이지
- **파일**: `lib/features/exceptions/exceptions_screen.dart` (신규)
- **하위 작업**:
  1. 현재 하자 탭 (DEFECT_FOR_SALE + RETURNING 아이템 목록)
  2. 반려 이력 탭 (inspection_rejections 전체)
  3. 플랫폼/상태 필터
  4. 반려 사진 갤러리 뷰
  5. 반려 상세 정보 (defect_type, reason, discount)

#### Task 2B-3: 물류 추적 페이지
- **파일**: `lib/features/logistics/logistics_screen.dart` (신규)
- **하위 작업**:
  1. 발송 이력 전체 목록 (shipments JOIN items + products)
  2. 월별/택배사별 통계 카드
  3. 아이템 상세로 이동 링크

#### Task 2B-4: 구매 내역 페이지
- **파일**: `lib/features/purchases/purchases_screen.dart` (신규)
- **하위 작업**:
  1. 전체 구매 이력 목록 (purchases JOIN items + products)
  2. 날짜/매입처/결제수단 필터
  3. 요약 통계 (총 구매액, VAT 환급 합계)

#### Task 2B-5: 인벤토리 UX 개선
- **파일**: `lib/features/inventory/inventory_screen.dart` (수정)
- **파일**: `lib/features/inventory/widgets/` (수정/신규)
- **하위 작업**:
  1. 정렬 옵션 확장 (구매가/등록가/판매가/구매일)
  2. 개인/샘플 필터 추가
  3. 확장 패널 (이미지 + 구매/판매 정보 인라인 표시)
  4. 판매중/재고/발송 그룹 탭
  5. Sticky 헤더 (SliverAppBar 또는 SliverPersistentHeader)

#### Task 2B-6: 대시보드 나머지
- **파일**: `lib/features/dashboard/dashboard_screen.dart` (수정)
- **하위 작업**:
  1. 브랜드 Top 6 Bar 차트 (fl_chart)
  2. 최근 활동 타임라인 (status_logs 최신 8건)
  3. 긴급 알림 카드 (발송 기한 초과 아이템)
  4. 캘린더 미니 위젯

#### Task 2B-7: 데이터 내보내기
- **파일**: `lib/core/services/data_export_service.dart` (신규)
- **하위 작업**:
  1. 전체 DB JSON 내보내기 (share_plus 또는 file_picker)
  2. 판매 내역 CSV 내보내기
  3. 재고 현황 CSV 내보내기

---

### Phase 2-C: 선택 기능 + 로컬앱 고유 기능

#### Task 2C-1: 캘린더 뷰
- **패키지**: `table_calendar`
- **하위 작업**:
  1. 월별 캘린더 UI
  2. 구매/판매/상태변경 날짜에 인디케이터 표시
  3. 날짜 탭 → 해당일 이벤트 목록

#### Task 2C-2: Google Drive 동기화
- **패키지**: `googleapis`, `google_sign_in`
- **하위 작업**:
  1. Google Sign-In 인증
  2. CRDT HLC 기반 충돌 해결 로직
  3. SQLite → JSON → Google Drive 업로드
  4. Google Drive → JSON → SQLite 다운로드/머지
  5. SyncMeta 기반 마지막 동기화 시점 추적
  6. 자동/수동 동기화 UI

#### Task 2C-3: 기타 UI 개선
- receipt_url 입력 필드 추가 (온라인 구매)
- 플랫폼 취소 세부 옵션 다이얼로그
- POIZON 백그라운드 자동 동기화 (WorkManager)

---

## 4. 작업 순서 권장안

```
Phase 2-A (핵심)    약 5개 태스크
  ├── 2A-4  대시보드 강화           ← 첫 작업 (기존 파일 수정, 빠른 성과)
  ├── 2A-1  판매 내역 페이지        ← 가장 큰 누락 기능
  ├── 2A-3  검수 반려 다이얼로그     ← 핵심 비즈니스 로직
  ├── 2A-5  SizePicker 고도화      ← 구매 UX 개선
  └── 2A-2  배치 구매 등록          ← 효율성 기능

Phase 2-B (중요)    약 7개 태스크
  ├── 2B-1  분석 대시보드           ← fl_chart 도입, 가치 높음
  ├── 2B-5  인벤토리 UX 개선        ← 메인 화면 품질 향상
  ├── 2B-6  대시보드 나머지         ← 차트 + 활동 로그
  ├── 2B-7  데이터 내보내기         ← 실용적
  ├── 2B-2  하자 관리 페이지        ← 전용 뷰
  ├── 2B-3  물류 추적 페이지        ← 전용 뷰
  └── 2B-4  구매 내역 페이지        ← 전용 뷰

Phase 2-C (선택)    약 3개 태스크
  ├── 2C-1  캘린더 뷰
  ├── 2C-2  Google Drive 동기화    ← 가장 복잡, 별도 스프린트 권장
  └── 2C-3  기타 UI 개선
```

---

## 5. 구현 현황 요약 통계

| 카테고리 | 웹앱 기능 수 | ✅ 완료 | 🔶 부분 | ❌ 미구현 | ➖ 해당없음 | 이식률 |
|---------|------------|---------|---------|----------|-----------|-------|
| 인증 | 4 | 0 | 0 | 0 | 4 | N/A |
| 대시보드 | 7 | 6 | 0 | 1 | 0 | 86% |
| 구매 관리 | 12 | 9 | 0 | 3 | 0 | 75% |
| 재고 목록 | 12 | 10 | 1 | 1 | 0 | 83% |
| 벌크 액션 | 10 | 10 | 0 | 0 | 0 | 100% |
| 아이템 상세 | 11 | 10 | 1 | 0 | 0 | 91% |
| 판매 관리 | 7 | 7 | 0 | 0 | 0 | 100% |
| 수수료 계산 | 8 | 8 | 0 | 0 | 0 | 100% |
| 검수 5분기 | 6 | 6 | 0 | 0 | 0 | 100% |
| 수선 관리 | 7 | 7 | 0 | 0 | 0 | 100% |
| 바코드/AI | 11 | 11 | 0 | 0 | 0 | 100% |
| 분석 | 9 | 9 | 0 | 0 | 0 | 100% |
| 하자 관리 | 5 | 5 | 0 | 0 | 0 | 100% |
| 물류 추적 | 4 | 4 | 0 | 0 | 0 | 100% |
| 캘린더 | 3 | 0 | 0 | 3 | 0 | 0% |
| 설정 | 5 | 5 | 0 | 0 | 0 | 100% |
| **전체** | **121** | **108** | **2** | **7** | **4** | **92%** |

> **인증 제외 전체 이식률: 약 92%** (117개 중 108개 완료 + 2개 부분 구현)
> **핵심 비즈니스 로직 이식률: ~99%** (상태 머신, 수수료 계산, 구매/판매 CRUD, 바코드/AI 스캔, 벌크 액션 전체)
> **전용 페이지/뷰 이식률: ~95%** (분석/하자/물류/구매/판매 페이지 완료, 캘린더만 미구현)
>
> **Phase 2-A 완료 (2026-03-25)**: 대시보드 강화, 판매 내역 페이지, SizePicker 고도화, AI 스캔→등록 사이즈 버그 수정
> **Phase 2-B 완료 (2026-03-25)**: 분석 대시보드(fl_chart), 하자/물류/구매 전용 페이지, 인벤토리 정렬 확장, 데이터 내보내기(JSON/CSV)
> **Phase 2-B+ 완료 (2026-03-25)**: Drawer 네비게이션(전체 페이지 접근성), 브랜드 Top6 차트(DASH-03), 검수 지연 경고(DASH-06), 개인/사업용 필터(INV-04), 인벤토리 정렬 토글 UI, 판매내역 정산완료 그룹핑 뷰, AI 스캔 사이즈 자동완성 버그 수정

---

## 6. 다음 세션 작업 (Phase 2-C + 잔여 이슈)

> 최종 업데이트: 2026-03-25

### 완료된 이슈 (이번 세션)
- ~~하자/물류/구매 페이지 네비게이션 미연결~~ → Drawer 추가로 해결
- ~~AI 스캔 사이즈 자동완성 버그~~ → `_loadSizeCharts` 캐시 조건 수정
- ~~AI 스캔 신규 상품 폼 전환~~ → 이미 구현 확인
- ~~개인/샘플 필터(INV-04)~~ → 토글 버튼 구현
- ~~브랜드 Top6 차트(DASH-03)~~ → fl_chart BarChart
- ~~인벤토리 정렬 드롭다운~~ → 최신순/오래된순 토글 버튼
- ~~판매 탭~~ → Drawer로 이동, 정산완료 그룹핑 뷰로 변경

### 스프린트 3: 인벤토리 UX 고도화

| # | 태스크 | 관련 ID | 복잡도 | 파일 |
|---|--------|---------|--------|------|
| 1 | 확장 패널 (이미지+구매/판매 정보 인라인) | INV-07 | 중 | `lib/features/inventory/widgets/grouped_list_view.dart` |
| 2 | 그룹 탭 (판매중: 사무실/포이즌보관 분리) | INV-08 | 중 | `lib/features/inventory/inventory_screen.dart` |
| 3 | 그룹 탭 (재고: 위치별) | INV-09 | 중 | 위와 동일 |
| 4 | 그룹 탭 (발송: 발송일+운송장별) | INV-10 | 중 | 위와 동일 |
| 5 | Sticky 헤더 (Sliver 리팩토링) | INV-12 | 높 | `lib/features/inventory/inventory_screen.dart` |

### 스프린트 4: 캘린더 + 대시보드 마무리

| # | 태스크 | 관련 ID | 복잡도 | 비고 |
|---|--------|---------|--------|------|
| 1 | 캘린더 전체 뷰 (월별 이벤트) | CAL-01~03 | 중 | `table_calendar` 패키지 추가 필요 |
| 2 | 대시보드 캘린더 미니 위젯 | DASH-04 | 낮 | 위 캘린더 완료 후 |

### 스프린트 5: Google Drive 동기화 (가장 복잡)

| # | 태스크 | 복잡도 | 비고 |
|---|--------|--------|------|
| 1 | Google Sign-In 인증 | 중 | `google_sign_in` 이미 의존성에 있음 |
| 2 | CRDT HLC 충돌 해결 로직 | 높 | `crdt` 패키지 이미 의존성에 있음 |
| 3 | SQLite → JSON → Drive 업로드 | 중 | `googleapis` 이미 의존성에 있음 |
| 4 | Drive → JSON → SQLite 머지 | 높 | SyncMeta 테이블 활용 |
| 5 | 자동/수동 동기화 UI | 낮 | 설정 화면에 추가 |

### 잔여 이슈 (우선순위 낮음)
- **상품 이미지 로컬 저장** — QR 스캔으로 가져온 상품 이미지의 로컬 캐시 저장 여부 확인 필요
- **receipt_url 입력** (PUR-09) — 온라인 구매 영수증 URL 필드
- **POIZON 자동 동기화** (POI-04) — WorkManager 백그라운드 타이머
