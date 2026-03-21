# POIZON API - Listing & Inventory (리스팅 및 재고)

> Base URL: `https://open.poizon.com`
> 모든 엔드포인트: **POST** 메서드

---

## 공통 General Parameters (모든 Listing API 동일)

| 파라미터 | 필수 | 타입 | 설명 | 예시 |
|----------|------|------|------|------|
| `app_key` | ✅ | String | Application Identifier | `app_key=your_app_key` |
| `access_token` | | String | Request Token (ERP/ISV 필수) | `access_token=your_access_token` |
| `timestamp` | ✅ | Long | 현재 타임스탬프 (밀리초) | `timestamp=1648888088814` |
| `sign` | ✅ | String | 서명 | `sign=the_sign_string` |
| `language` | ✅ | String | 언어: zh, zh-TW, en, ja, ko, fr | `language=en` |
| `timeZone` | ✅ | String | 타임존 | `timeZone=Asia/Shanghai` |

---

## Manual Listing (수동 리스팅 등록)

### 1. Manual Listing (Ship-to-verify)

> Ship-to-verify 방식의 새 리스팅 등록. 셀러 자체 창고에서 직접 발송.

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/submit-bid/normal-autonomous-bidding`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/submit-bid/normal-autonomous-bidding`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `requestId` | ✅ | String | 고유 요청 코드 (매 요청마다 중복 불가, 예: e4fb8ed1-319d-4de6-0000-909) |
| `globalSkuId` | | Number | 글로벌 SKU ID. skuId와 동시에 비어 있을 수 없음. skuId 사용 권장 |
| `skuId` | | Number | DW skuId. globalSkuId와 동시에 비어 있을 수 없음. skuId 사용 권장 |
| `price` | ✅ | Number | 리스팅 통화 최소 단위 가격 (예: 13000 = $130.00) |
| `quantity` | ✅ | Number | 리스팅 수량 |
| `sizeType` | | String | 사이즈 타입 (EU, US, UK, CN, JP) |
| `countryCode` | ✅ | String | 셀러 발송 지역 (US, CN, HK, TW, MO, JP, KR, FR, IT, GB, ES, DE) |
| `deliveryCountryCode` | | String | 배송 국가 코드 |
| `currency` | | String | 리스팅 통화 (CNY, USD, HKD, JPY, SGD, EUR, KRW) |

---

### 2. Manual Listing (Pre-sale)

> Pre-sale(선판매) 방식의 새 리스팅 등록. 상품 입고 전 선판매.

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/submit-bid/pre-sell-autonomous-bidding`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/submit-bid/pre-sell-autonomous-bidding`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `requestId` | ✅ | String | 고유 요청 코드 |
| `globalSkuId` | | Number | 글로벌 SKU ID |
| `skuId` | | String | DW skuId |
| `price` | ✅ | Number | 리스팅 통화 최소 단위 가격 |
| `quantity` | ✅ | Number | 리스팅 수량 |
| `sizeType` | | String | 사이즈 타입 (EU, US, UK, CN, JP) |
| `preAging` | ✅ | Number | **유효 기간 일수 (Pre-sale 일수)** |
| `countryCode` | ✅ | String | 셀러 발송 지역 |
| `deliveryCountryCode` | | String | 배송 국가 코드 |
| `currency` | | String | 리스팅 통화 |

---

### 3. Manual Listing (Consignment)

> Consignment(위탁) 방식의 새 리스팅 등록. POIZON 창고에 보관된 상품.

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/submit-bid/deposit-bidding`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/submit-bid/deposit-bidding`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `requestId` | ✅ | String | 고유 요청 코드 |
| `globalSkuId` | | Number | 글로벌 SKU ID |
| `skuId` | | String | DW skuId |
| `price` | ✅ | Number | 리스팅 통화 최소 단위 가격 |
| `quantity` | ✅ | Number | 리스팅 수량 |
| `sizeType` | | String | 사이즈 타입 (EU, US, UK, CN, JP) |
| `countryCode` | ✅ | String | 셀러 발송 지역 |
| `deliveryCountryCode` | | String | 배송 국가 코드 |
| `currency` | | String | 리스팅 통화 |

---

### 4. Manual Listing (Direct)

> Direct 방식의 리스팅 등록.

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/submit-bid/direct-autonomous-bidding`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/submit-bid/direct-autonomous-bidding`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `requestId` | ✅ | String | 고유 요청 코드 |
| `globalSkuId` | | Number | 글로벌 SKU ID |
| `skuId` | | Number | DW skuId |
| `price` | ✅ | Number | 리스팅 통화 최소 단위 가격 |
| `quantity` | ✅ | Number | 리스팅 수량 |
| `sizeType` | | String | 사이즈 타입 (EU, US, UK, CN, JP) |
| `countryCode` | ✅ | String | 국가 코드 |
| `deliveryCountryCode` | ✅ | String | 배송 국가 코드 |
| `currency` | | String | 리스팅 통화 |

---

## Update Listing (리스팅 수정)

### 5. Update Manual Listing (Ship-to-verify)

> Ship-to-verify 리스팅 수정

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/update-bid/normal-autonomous-bidding`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/update-bid/normal-autonomous-bidding`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `requestId` | ✅ | String | 고유 요청 코드 |
| `globalSkuId` | | Number | 글로벌 SKU ID |
| `skuId` | | Number | DW skuId |
| `sellerBiddingNo` | ✅ | String | **셀러 리스팅 고유 식별자** (초기 리스팅 또는 업데이트 인터페이스에서 획득) |
| `price` | ✅ | Number | 리스팅 통화 최소 단위 가격 |
| `oldQuantity` | ✅ | Number | 리스팅 잔여 재고 수량 |
| `quantity` | ✅ | Number | 리스팅 수량 |
| `countryCode` | ✅ | String | 셀러 발송 지역 |
| `currency` | | String | 리스팅 통화 |

---

### 6. Update Manual Listing (Pre-sale)

> Pre-sale 리스팅 수정

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/update-bid/pre-sell-autonomous-bidding`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/update-bid/pre-sell-autonomous-bidding`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `requestId` | ✅ | String | 고유 요청 코드 |
| `globalSkuId` | | Number | 글로벌 SKU ID |
| `skuId` | | String | DW skuId |
| `price` | ✅ | Number | 리스팅 통화 최소 단위 가격 |
| `oldQuantity` | ✅ | Number | 리스팅 잔여 재고 수량 |
| `quantity` | ✅ | Number | 리스팅 수량 |
| `countryCode` | ✅ | String | 셀러 발송 지역 |
| `currency` | | String | 리스팅 통화 |

---

### 7. Update Manual Listing (Consignment)

> Consignment 리스팅 수정

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/update-bid/deposit-bidding`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/update-bid/deposit-bidding`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `requestId` | ✅ | String | 고유 요청 코드 |
| `globalSkuId` | | Number | 글로벌 SKU ID |
| `skuId` | | String | DW skuId |
| `price` | ✅ | Number | 리스팅 통화 최소 단위 가격 |
| `oldQuantity` | ✅ | Number | 리스팅 잔여 재고 수량 |
| `quantity` | ✅ | Number | 리스팅 수량 |
| `countryCode` | ✅ | String | 셀러 발송 지역 |
| `currency` | | String | 리스팅 통화 |

---

### 8. Update Manual Listing (Direct)

> Direct 리스팅 수정

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/update-bid/direct-autonomous-bidding`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/update-bid/direct-autonomous-bidding`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `requestId` | ✅ | String | 고유 요청 코드 |
| `globalSkuId` | | Number | 글로벌 SKU ID |
| `skuId` | | Number | DW skuId |
| `sellerBiddingNo` | ✅ | String | 셀러 리스팅 고유 식별자 |
| `price` | ✅ | Number | 리스팅 통화 최소 단위 가격 |
| `oldQuantity` | ✅ | Number | 리스팅 잔여 재고 수량 |
| `quantity` | ✅ | Number | 리스팅 수량 |
| `countryCode` | ✅ | String | 국가 코드 |
| `currency` | | String | 리스팅 통화 |

---

## Cancel Listing (리스팅 취소)

### 9. Cancel Listing

> 기존 리스팅 취소/철회

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/cancel-bid/cancel-bidding`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/cancel-bid/cancel-bidding`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `sellerBiddingNo` | | String | 셀러 리스팅 고유 식별자 (초기 리스팅 또는 업데이트에서 획득) |

---

## Query Listing (리스팅 조회)

### 10. Query Listing List

> 현재 상품 리스팅 목록 조회. 상품 상태, 가격, 재고 수준 등 상세 정보 제공.

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/retrieve-bid/general-type-bidding-list`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/retrieve-bid/general-type-bidding-list`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `biddingType` | | Number | 리스팅 유형 (20: Ship-to-Verify/Pre-sale, 25: Consignment, 27: Direct, 90: Defective goods) |
| `saleType` | | Number | 판매 유형 (0: Ship-to-Verify, 7: Pre-sale) |
| `tradeStatus` | | Number | 리스팅 상태 (1: 취소됨, 2: 성공, 3: 매진) |
| `pageSize` | ✅ | Number | 페이지당 항목 수 (최대 100) |
| `sellerBiddingNoList` | | Array | 리스팅 번호 리스트 (예: ["1234"]) |
| `exclusiveStartOffsetId` | | Number | 페이지네이션 ID (첫 요청 시 0, 이후 응답의 lastOffsetId 사용) |
| `globalSpuId` | | Number | 글로벌 SPU ID |
| `spuId` | | Number | DW spuId (권장) |
| `skuId` | | Long | DW skuId (권장) |
| `globalSkuId` | | Long | 글로벌 SKU ID |
| `region` | ✅ | String | 셀러 발송 지역 |

**Request 예시:**
```json
{
  "uid": 10000103,
  "language": "en",
  "timeZone": "Asia/Shanghai",
  "tradeStatus": 2,
  "region": "HK",
  "saleType": 7,
  "exclusiveStartOffsetId": 0,
  "pageSize": 1
}
```

**Response 주요 구조:**
```json
{
  "code": 200,
  "data": {
    "list": [{
      "id": 169941,
      "sellerBiddingNo": "112020032025413023",
      "uid": 10000103,
      "biddingType": 25,
      "saleType": 7,
      "tradeStatus": 2,
      "quantity": 2,
      "spuId": 30741091,
      "skuId": 602930224,
      "globalSpuId": 3000000046,
      "globalSkuId": 3000000117,
      "price": 99900,
      "currency": "USD",
      "countryCode": "US",
      "deliveryCountryCode": "US",
      "effectiveTime": "2024-01-19 11:46:57",
      "createTime": "2024-01-19 11:46:57",
      "spuTitle": "Clear52301",
      "onSaleQuantity": 0,
      "holidayMode": 0
    }],
    "lastOffsetId": 169941,
    "pageSize": 1
  }
}
```

---

### 11. Query Listing List (Consignment)

> Consignment 리스팅 목록 조회

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/retrieve-bid/deposit-type-bidding-list`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/retrieve-bid/deposit-type-bidding-list`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `pageSize` | ✅ | Number | 페이지당 항목 수 (최대 100) |
| `exclusiveStartOffsetId` | | Number | 시작 ID (쿼리 결과에 이 ID 미포함) |

---

### 12. Query listing list (Simplified Version)

> 간소화된 리스팅 목록 조회

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/retrieve-bid/general-type-bidding-list/simple`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/retrieve-bid/general-type-bidding-list/simple`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `exclusiveStartOffsetId` | | Long | 페이지네이션 커서 |
| `pageSize` | | Integer | 페이지당 항목 수 |
| `biddingType` | | Integer | 리스팅 유형 |
| `tradeStatus` | | Integer | 거래 상태 (1: 취소, 2: 성공. 미입력 시 기본값 2) |
| `sellerBiddingNoList` | | Array | 셀러 리스팅 번호 리스트 |
| `globalSpuIds` | | Array | 글로벌 SPU ID 리스트 (최대 10개) |
| `globalSkuIds` | | Array | 글로벌 SKU ID 리스트 (최대 20개) |
| `region` | | String | Region 코드 |
| `saleType` | | Integer | 판매 유형 |
| `spuIds` | | Array | DW SPU ID 리스트 (최대 10개) |
| `skuIds` | | Array | DW SKU ID 리스트 (최대 20개) |
| `merchantSpuId` | | String | 셀러 SPU ID |
| `merchantSkuId` | | String | 셀러 SKU ID (사용 시 merchantSpuId 필수) |

---

## Listing Recommendations (리스팅 추천)

### 13. (Get Lowest Price) Listing Recommendations

> 개별 리스팅 추천 및 최저가 조회

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/recommend-bid/price`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/recommend-bid/price`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `skuId` | | Number | DW skuId (skuId와 globalSkuId 중 최소 하나 필수. skuId 사용 권장) |
| `globalSkuId` | | Number | 글로벌 SKU ID |
| `biddingType` | ✅ | Number | 리스팅 유형 (20: Ship-to-Verify, 25: Consignment) |
| `saleType` | | Number | 판매 유형 (7: Pre-sale, 0: Ship-to-Verify) |
| `region` | ✅ | String | 셀러 발송 지역 |

---

### 14. (Get Lowest Price) Listing Recommendations - Batch

> 배치 리스팅 추천 및 최저가 조회

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/recommend-bid/batchPrice`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/recommend-bid/batchPrice`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `skuIds` | | Array | DW skuId 리스트 (최대 20개. skuIds와 globalSkuIdList 중 최소 하나 필수) |
| `globalSkuIdList` | | Array | 글로벌 SKU ID 리스트 (최대 20개) |
| `biddingType` | ✅ | Number | 리스팅 유형 (20: Spot, 25: Consignment) |
| `saleType` | | Number | 판매 유형 (7: preSale) |
| `region` | ✅ | String | 셀러 발송 지역 |

---

## Automatic Bidding (자동 입찰)

### 15. Submit Automatic Bidding

> 자동 팔로우업 입찰 제출 또는 취소

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/auto-follow-bidding/submit`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/auto-follow-bidding/submit`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `biddingNo` | ✅ | String | 리스팅 번호 (예: 112020032025415342) |
| `lowestPrice` | | Long | 최저 팔로우 가격 (예: 60111) |
| `followType` | ✅ | Integer | 팔로우 유형: **3**: 아시아 최저가 팔로우, **4**: 로컬 최저가 팔로우, **5**: 아시아 최저가보다 항상 한 단계 낮게, **6**: 로컬 최저가보다 항상 한 단계 낮게 |
| `autoSwitch` | ✅ | Boolean | true: 자동 팔로우 제출, false: 자동 팔로우 취소 |
| `countryCode` | ✅ | String | 셀러 발송 지역 |
| `currency` | | String | 리스팅 통화 (CNY, USD, HKD, JPY, SGD, EUR, KRW) |

---

### 16. Query Automatic Follow-Up Bidding List

> 자동 팔로우업 입찰 목록 조회

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/auto-follow-bidding/list`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/auto-follow-bidding/list`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `biddingNoList` | | Array | 리스팅 번호 리스트 (세 파라미터 중 최소 하나 필수) |
| `skuIdList` | | Array | DW skuId 리스트 |
| `globalSkuIdList` | | Array | 글로벌 SKU ID 리스트 |

> ⚠️ `biddingNoList`, `skuIdList`, `globalSkuIdList` 중 최소 하나는 입력해야 합니다.

---

## Inventory (재고)

### 17. Query Inventory (Consignment)

> Consignment 방식 재고 조회

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/retrieve-deposit/list`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/retrieve-deposit/list`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `haveDefective` | | Number | 불량 재고 여부 (0: 없음, 1: 있음) |
| `pageNum` | ✅ | Number | 현재 페이지 번호 |
| `pageSize` | ✅ | Number | 페이지당 항목 수 (최대 50) |
| `globalSpuIdList` | | Array | 글로벌 SPU ID 리스트 (최대 20개) |
| `globalSkuIdList` | | Array | 글로벌 SKU ID 리스트 (최대 20개) |
| `spuIds` | | Array | DW spuId 리스트 (최대 20개) |
| `skuIds` | | Array | DW skuId 리스트 (최대 20개) |
| `warehouseNo` | | String | 파크(창고) 코드 (예: YS01) |
| `region` | ✅ | String | 셀러 발송 지역 |

---

## Recovery (복구)

### 18. Recovery of Weak Interception Bidding

> 약한 차단 입찰 복구

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/submit-bid/biddingRecovery`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/submit-bid/biddingRecovery`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `biddingNoList` | ✅ | Array | 리스팅 번호 리스트 |

---

## 엔드포인트 URL 빠른 참조

| # | API명 (축약) | Endpoint Path |
|---|-------------|---------------|
| 1 | Manual Listing (Ship-to-verify) | `.../submit-bid/normal-autonomous-bidding` |
| 2 | Manual Listing (Pre-sale) | `.../submit-bid/pre-sell-autonomous-bidding` |
| 3 | Manual Listing (Consignment) | `.../submit-bid/deposit-bidding` |
| 4 | Manual Listing (Direct) | `.../submit-bid/direct-autonomous-bidding` |
| 5 | Update Listing (Ship-to-verify) | `.../update-bid/normal-autonomous-bidding` |
| 6 | Update Listing (Pre-sale) | `.../update-bid/pre-sell-autonomous-bidding` |
| 7 | Update Listing (Consignment) | `.../update-bid/deposit-bidding` |
| 8 | Update Listing (Direct) | `.../update-bid/direct-autonomous-bidding` |
| 9 | Cancel Listing | `.../cancel-bid/cancel-bidding` |
| 10 | Query Listing List | `.../retrieve-bid/general-type-bidding-list` |
| 11 | Query Listing List (Consignment) | `.../retrieve-bid/deposit-type-bidding-list` |
| 12 | Query Listing List (Simplified) | `.../retrieve-bid/general-type-bidding-list/simple` |
| 13 | Listing Recommendations | `.../recommend-bid/price` |
| 14 | Listing Recommendations - Batch | `.../recommend-bid/batchPrice` |
| 15 | Submit Automatic Bidding | `.../auto-follow-bidding/submit` |
| 16 | Query Auto Follow-Up List | `.../auto-follow-bidding/list` |
| 17 | Query Inventory (Consignment) | `.../retrieve-deposit/list` |
| 18 | Recovery of Weak Interception | `.../submit-bid/biddingRecovery` |

---

## 참고: 주요 코드 값

### biddingType (리스팅 유형)
| 값 | 설명 |
|----|------|
| 20 | Ship-to-Verify / Pre-sale |
| 25 | Consignment |
| 27 | Direct |
| 90 | Defective goods |

### saleType (판매 유형)
| 값 | 설명 |
|----|------|
| 0 | Ship-to-Verify |
| 7 | Pre-sale |

### tradeStatus (리스팅 상태)
| 값 | 설명 |
|----|------|
| 1 | Listing canceled (취소됨) |
| 2 | Listing successful (성공) |
| 3 | Listing sell out (매진) |

### followType (자동 팔로우 유형)
| 값 | 설명 |
|----|------|
| 3 | 아시아 최저가 팔로우 |
| 4 | 로컬 최저가 팔로우 |
| 5 | 아시아 최저가보다 항상 한 단계 낮게 |
| 6 | 로컬 최저가보다 항상 한 단계 낮게 |

### 가격 단위
> price 필드는 **통화의 최소 단위**로 입력합니다.
> 예: USD $130.00 → `price=13000` (센트 단위)

### Region 코드
`US, CN, HK, TW, MO, JP, KR, FR, IT, GB, ES, DE`

### Currency 코드
`CNY, USD, HKD, JPY, SGD, EUR, KRW`

### sizeType
`EU, US, UK, CN, JP`
