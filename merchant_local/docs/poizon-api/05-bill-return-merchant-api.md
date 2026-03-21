# POIZON API - Bill / Return / Merchant

> Base URL: `https://open.poizon.com`

---

## 공통 General Parameters

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `app_key` | ✅ | String | Application Identifier |
| `access_token` | | String | Request Token (ERP/ISV 필수) |
| `timestamp` | ✅ | Long | 현재 타임스탬프 (밀리초) |
| `sign` | ✅ | String | 서명 |
| `language` | ✅ | String | 언어: zh, zh-TW, en, ja, ko, fr |
| `timeZone` | ✅ | String | 타임존 (예: Asia/Shanghai) |

---

# A. Bill (정산) API

### 1. Generate Billing Cycle Invoice

> 특정 정산 주기의 인보이스 생성. 재무 거래 추적 및 결제 관리에 활용.

- **Method:** `GET`
- **Endpoint:** `GET /dop/api/v1/pop/api/v1/bill/generate`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/bill/generate`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `bill_no` | ✅ | String | 청구서 번호 (예: 234543) |

**Response 예시:**
```json
{
  "code": 200,
  "data": "exportD1/BillMerchantBill1608187247945.xlsx",
  "msg": ""
}
```

> 응답의 `data`는 다운로드 키로 사용됩니다. `Download Billing Cycle Invoice` API에 전달.

---

### 2. Download Billing Cycle Invoice

> 정산 주기 인보이스 다운로드

- **Method:** `GET`
- **Endpoint:** `GET /dop/api/v1/pop/api/v1/bill/export`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/bill/export`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `key` | ✅ | String | 다운로드 키 (Generate API 응답에서 획득, 예: 2112345526491) |

---

### 3. Get Billing Cycle Reconciliation List

> 정산 주기 대사 목록 조회

- **Method:** `GET`
- **Endpoint:** `GET /dop/api/v1/pop/api/v1/bill/period_list`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/bill/period_list`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `bill_no` | | String | 청구서 번호 |
| `bill_start_time` | | String | 청구 시작일 (yyyy-MM-dd, 미입력 시 30일 전, **최대 간격 30일**) |
| `bill_end_time` | | String | 청구 종료일 (yyyy-MM-dd, 미입력 시 현재 시간, **최대 간격 30일**) |
| `page_no` | | Integer | 페이지 번호 (기본 1) |
| `page_size` | | Integer | 페이지 사이즈 (기본 20, 최대 100) |

---

### 4. Get Return Orders

> 반품 주문 조회 (정산 관련)

- **Method:** `POST`
- **Endpoint:** `POST /dop/api/v1/pop/api/v1/bill/customer_return_list`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/bill/customer_return_list`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `page_no` | | Integer | 페이지 번호 (기본 1) |
| `page_size` | | Integer | 페이지 사이즈 (기본 20, 최대 100) |
| `order_no` | | String | 주문 번호 (예: 2100024543298) |
| `global_spu_id` | | Long | 글로벌 SPU ID |
| `spu_id` | | Long | DW spuId |
| `order_type` | | String | 주문 유형 (아래 표 참조) |
| `real_stmt_start_time` | | String | 정산 시작일 (yyyy-MM-dd, 미입력 시 30일 전, **최대 간격 30일**) |
| `real_stmt_end_time` | | String | 정산 종료일 (yyyy-MM-dd, 미입력 시 현재 시간, **최대 간격 30일**) |
| `refund_started_time` | | String | 반품 시작일 (yyyy-MM-dd) |
| `refund_end_time` | | String | 반품 종료일 (yyyy-MM-dd) |

---

### 5. Get Real-Time Reconciliation List

> 실시간 대사 목록 조회

- **Method:** `GET`
- **Endpoint:** `GET /dop/api/v1/pop/api/v1/bill/realtime_list`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/bill/realtime_list`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `order_no` | | String | 주문 번호 (예: 2112345526491) |
| `settle_start_time` | | String | 정산 시작일 (yyyy-MM-dd, 미입력 시 30일 전, **최대 간격 30일**) |
| `settle_end_time` | | String | 정산 종료일 (yyyy-MM-dd, 미입력 시 현재 시간, **최대 간격 30일**) |
| `page_no` | | Integer | 페이지 번호 (기본 1) |
| `page_size` | | Integer | 페이지 사이즈 (기본 20, 최대 100) |

---

# B. Return (반품/출고) API

### 6. Check the return address

> 반품 주소 확인 (파라미터 없음, 설정된 반품 주소 반환)

- **Method:** `POST`
- **Endpoint:** `POST /dop/api/v1/pop/api/v1/return/queryAddress`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/return/queryAddress`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| (없음) | | | Business Parameters 없음 |

---

### 7. Get All Address

> 모든 주소 조회 (파라미터 없음)

- **Method:** `POST`
- **Endpoint:** `POST /dop/api/v1/pop/api/v1/return/queryAddress`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/return/queryAddress`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| (없음) | | | Business Parameters 없음 |

---

### 8. Get date information for pick-up from outbound

> 출고 픽업 예약 날짜 정보 조회

- **Method:** `POST`
- **Endpoint:** `POST /dop/api/v1/pop/api/v1/return/queryAppointmentDate`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/return/queryAppointmentDate`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `warehouseCode` | ✅ | String | 창고 코드 (예: lax01) |

---

### 9. Query the inventory information to be returned

> 반품 예정 재고 정보 조회

- **Method:** `POST`
- **Endpoint:** `POST /dop/api/v1/pop/api/v1/return/queryWhInvList`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/return/queryWhInvList`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `warehouseCodeList` | | Array | 창고 코드 리스트 (반품 파라미터의 warehouseFilter에서 획득, 예: lax01) |
| `searchTerm` | | String | 검색어 (최대 100자). 창고 영수증 번호, 상품명, 브랜드명, 품번 검색 |
| `shots` | | Long | 정렬 키의 최대 ID (예: 0) |
| `pageSize` | | Integer | 스크롤 페이지 사이즈 (예: 20) |
| `inventoryLevelList` | | Array | 재고 레벨 (반품 파라미터의 inventorySaleStatusFilter에서 획득, 예: defect_sale) |
| `fulBizTypeList` | | Array | 비즈니스 유형 (반품 파라미터의 fulBizTypeFilter에서 획득, 예: spot) |

---

### 10. Outbound order creation

> 출고 주문 생성

- **Method:** `POST`
- **Endpoint:** `POST /dop/api/v1/pop/api/v1/return/create`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/return/create`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `warehouseCode` | ✅ | String | 창고 코드 (예: lax01) |
| `returnMethodCode` | ✅ | String | 반품 방법: **self_pickup**(직접 픽업), **online_logistics**(택배 반품) |
| `returnAddressId` | | Long | 반품 주소 ID (택배 반품 시 필수, 예: 8362) |
| `logisticsCarrierCode` | | String | 반품 물류 운송사 코드 (택배 반품 시 필수, 예: JD) |
| `SelfpickupapPointtime` | | Long | 직접 픽업 예약일 (직접 픽업 시 필수, 밀리초 타임스탬프. queryAppointmentDate API로 조회) |
| `itemList` | ✅ | Array | 반품 상세 목록 |

---

### 11. Outbound order list query

> 출고 주문 목록 조회

- **Method:** `POST`
- **Endpoint:** `POST /dop/api/v1/pop/api/v1/return/queryList`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/return/queryList`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `searchTerm` | | String | 검색어 (최대 100자). 상품명, 브랜드, 품번, 위탁 영수증 번호, 주문 번호 검색 |
| `outboundStatusList` | | Array | 출고 상태: **packing**(포장중), **wait_outbound**(출고 대기), **shipped_outbound**(출고 완료), **signed**(수취 완료) |
| `warehouseCode` | | String | 창고 코드 (예: IT02) |
| `outboundTypeList` | | Array | 출고 유형: **seller_outbound**(셀러 회수), **auto_outbound**(자동 반품) |
| `shots` | | Long | 정렬 키의 최대 ID (예: 0) |
| `pageSize` | | Integer | 스크롤 페이지 사이즈 (예: 20) |

---

### 12. Sign for Outbound Receipt

> 출고 수취 서명 확인

- **Method:** `POST`
- **Endpoint:** `POST /dop/api/v1/pop/api/v1/return/sign`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/return/sign`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `outboundApplyNo` | ✅ | String | 출고 주문 번호 (예: OA1111080582) |

---

### 13. Details of outbound order

> 출고 주문 상세 조회

- **Method:** `POST`
- **Endpoint:** `POST /dop/api/v1/pop/api/v1/return/getInfo`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/return/getInfo`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `outboundApplyNo` | ✅ | String | 출고 주문 번호 (예: JS240216000024202462) |

---

# C. Merchant (셀러 관리) API

### 14. Get Announcement Details

> 공지사항 상세 조회

- **Method:** `POST`
- **Endpoint:** `POST /dop/api/v1/pop/api/v1/announce/detail`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/announce/detail`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `noticeId` | ✅ | String | 암호화된 공지사항 ID (예: MNbAqvrMZVQs8q7TDbc9Hw==) |

---

### 15. Query merchant's sku code

> 셀러 SKU 코드 조회

- **Method:** `POST`
- **Endpoint:** `POST /dop/api/v1/pop/api/v1/merchant/articleNumber/query`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/merchant/articleNumber/query`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `spuIdList` | | Array | DW spu ID 리스트 (예: [1234233323, 123443434345]) |
| `skuIdList` | | Array | DW sku ID 리스트 (예: [1234233323, 123443434345]) |
| `merchantSkuCodes` | | Array | 셀러 SKU 코드 리스트 (예: ["1234233323", "123443434345"]) |

> 세 파라미터 중 최소 하나는 입력해야 합니다.

---

### 16. Modify merchant's sku code

> 셀러 SKU 코드 수정

- **Method:** `POST`
- **Endpoint:** `POST /dop/api/v1/pop/api/v1/merchant/articleNumber/modify`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/merchant/articleNumber/modify`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `merchantSkuInfo` | | Object | 셀러 SKU 코드 수정 정보 |

**merchantSkuInfo 하위 필드:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `skuId` | Long | DW skuId (예: 600015984) |
| `merchantSkuCode` | String | 셀러 SKU 코드 (예: "dddddd") |

**Request 예시:**
```json
{
  "merchantSkuInfo": {
    "skuId": 600015984,
    "merchantSkuCode": "dddddd"
  }
}
```

**Response 예시:**
```json
{
  "code": 200,
  "data": {
    "merchantArticleNumberDtoList": [{
      "title": "commodity-df209de1f89f-lol",
      "articleNumber": "lolCX-4234ea01",
      "skuId": 6041130674,
      "spuId": 1001097156,
      "sizeInfos": [
        {"sizeKey": "US", "value": "3"},
        {"sizeKey": "EU Code", "value": "36"},
        {"sizeKey": "CHN", "value": "36"}
      ],
      "merchantSkuCode": "20241113133642",
      "globalSkuId": 12000001778,
      "globalSpuId": 12000008141
    }]
  }
}
```

---

## 엔드포인트 URL 빠른 참조

### Bill

| # | API명 | Method | Endpoint Path |
|---|-------|--------|---------------|
| 1 | Generate Billing Cycle Invoice | GET | `.../bill/generate` |
| 2 | Download Billing Cycle Invoice | GET | `.../bill/export` |
| 3 | Get Billing Cycle Reconciliation List | GET | `.../bill/period_list` |
| 4 | Get Return Orders | POST | `.../bill/customer_return_list` |
| 5 | Get Real-Time Reconciliation List | GET | `.../bill/realtime_list` |

### Return

| # | API명 | Endpoint Path |
|---|-------|---------------|
| 6 | Check the return address | `.../return/queryAddress` |
| 7 | Get All Address | `.../return/queryAddress` |
| 8 | Get date info for pick-up | `.../return/queryAppointmentDate` |
| 9 | Query inventory to be returned | `.../return/queryWhInvList` |
| 10 | Outbound order creation | `.../return/create` |
| 11 | Outbound order list query | `.../return/queryList` |
| 12 | Sign for Outbound Receipt | `.../return/sign` |
| 13 | Details of outbound order | `.../return/getInfo` |

### Merchant

| # | API명 | Endpoint Path |
|---|-------|---------------|
| 14 | Get Announcement Details | `.../announce/detail` |
| 15 | Query merchant's sku code | `.../merchant/articleNumber/query` |
| 16 | Modify merchant's sku code | `.../merchant/articleNumber/modify` |

---

## 참고: 주요 코드 값

### order_type (반품 주문 유형 - Bill 섹션)

| 값 | 설명 |
|----|------|
| 0 | Regular Stock (일반 재고) |
| 1 | Regular Pre-sale (일반 선판매) |
| 2 | Immediate Cash (즉시 현금) |
| 3 | Cross-border (크로스보더) |
| 4 | Speed Plus |
| 5 | Consignment (위탁) |
| 6 | Warehousing (입고) |
| 7 | Speed Stock |
| 8 | Speed Pre-sale |
| 9 | Warehousing Deposit Pre-sale |
| 10 | (Non-warehousing) Deposit Pre-sale |
| 15 | Virtual Goods (가상 상품) |
| 20 | Overseas (해외) |
| 21 | Blind Box (블라인드 박스) |
| 23 | Service Order (서비스 주문) |
| 26 | Brand Direct Delivery (브랜드 직배송) |
| 36 | Crowdfunding (크라우드펀딩) |
| 38 | New Deposit Pre-sale |
| 100 | Limited Time Discount Activity (타임 세일) |
| 1000 | Auction Brand Direct Delivery |
| 1001 | Auction Personal Consignment |
| 1002 | Auction Enterprise Warehousing |

### outboundStatus (출고 상태)

| 값 | 설명 |
|----|------|
| `packing` | 포장 중 |
| `wait_outbound` | 출고 대기 |
| `shipped_outbound` | 출고 완료 |
| `signed` | 수취 완료 |

### outboundType (출고 유형)

| 값 | 설명 |
|----|------|
| `seller_outbound` | 셀러 회수 |
| `auto_outbound` | 자동 반품 |

### returnMethodCode (반품 방법)

| 값 | 설명 |
|----|------|
| `self_pickup` | 직접 픽업 |
| `online_logistics` | 택배 반품 |

### stockStatus (위탁 신청 상태)

| 값 | 설명 |
|----|------|
| 300 | 심사 대기 (Pending Review) |
| 400 | 승인 (Approved) |
| 500 | 반려 (Rejected) |
| 600 | 취소 (Cancelled) |

### 날짜 형식 및 제한

> Bill 관련 날짜 파라미터는 모두 `yyyy-MM-dd` 형식이며, **시작~종료 최대 간격은 30일**입니다.
> 미입력 시 시작일은 30일 전, 종료일은 현재 시간이 기본값입니다.
