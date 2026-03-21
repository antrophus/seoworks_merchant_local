# POIZON API - Item (상품 조회)

> Base URL: `https://open.poizon.com`
> Base Path: `/dop/api/v1/pop/api/v1/intl-commodity/`
> 모든 엔드포인트: **POST** 메서드

---

## 공통 General Parameters (모든 Item API 동일)

| 파라미터 | 필수 | 타입 | 설명 | 예시 |
|----------|------|------|------|------|
| `app_key` | ✅ | String | Application Identifier | `app_key=your_app_key` |
| `access_token` | | String | Request Token (ERP/ISV 필수) | `access_token=your_access_token` |
| `timestamp` | ✅ | Long | 현재 타임스탬프 (밀리초) | `timestamp=1648888088814` |
| `sign` | ✅ | String | 서명 | `sign=the_sign_string` |
| `language` | ✅ | String | 언어: zh, zh-TW, en, ja, ko, fr | `language=en` |
| `timeZone` | ✅ | String | 타임존 | `timeZone=Asia/Shanghai` |

---

## 1. Query SPU Basic Information by Article Number

> 품번(Article Number)으로 SPU 기본 정보 조회. **퍼지 검색** 지원 (대소문자, 공백, 언더스코어 포함)

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/intl-commodity/intl/spu/spu-basic-info/by-article-number`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/intl-commodity/intl/spu/spu-basic-info/by-article-number`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `articleNumber` | ✅ | String | Article Number (품번) |
| `region` | ✅ | String | Region (US, CN, HK, TW, MO, JP, KR, FR, IT, GB, ES, DE) |
| `pageNum` | | Integer | Page Number |
| `pageSize` | | Integer | Page Size |

---

## 2. Query Spu Basic Information by Brand ID with Scroll Pagination (Multilingual & Batch Support)

> 브랜드 ID로 SPU 기본 정보 조회. 스크롤 페이지네이션 지원.

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/intl-commodity/intl/spu/spu-basic-info/scroll-by-brandId`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/intl-commodity/intl/spu/spu-basic-info/scroll-by-brandId`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `brandIdList` | ✅ | Array | 브랜드 ID 리스트 |
| `scrollId` | ✅ | String | 첫 조회 시 null. 이후 응답의 scrollId 값 전달. null 반환 시 마지막 페이지 |
| `size` | | Integer | 조회 건수 |

**Request 예시:**
```json
{
  "scrollId": "434534534534",
  "brandIdList": [144],
  "pageSize": 2,
  "pageNum": 1
}
```

---

## 3. Query SKU and SPU basic information by barcode (multi-language & batch & pagination)

> 바코드로 SKU/SPU 기본 정보 조회. 다국어, 배치, 페이지네이션 지원.

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/intl-commodity/intl/sku/sku-basic-info/by-barcodes`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/intl-commodity/intl/sku/sku-basic-info/by-barcodes`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `barcodes` | ✅ | Array | 바코드 리스트 (최대 100개) |
| `sellerStatusEnable` | | Boolean | 셀러 비즈니스 라인 상품 상태 필터 |
| `buyStatusEnable` | | Boolean | 바이어 비즈니스 라인 상품 상태 필터 |
| `pageSize` | | Integer | 페이지 사이즈 |
| `pageNum` | | Integer | 페이지 번호 |

---

## 4. Query Sku&Spu basic information based on DW spuId

> DW(得物) spuId로 SKU/SPU 기본 정보 조회

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/intl-commodity/intl/sku/sku-basic-info/by-spu`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/intl-commodity/intl/sku/sku-basic-info/by-spu`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `spuIds` | | Array | DW spuId 리스트 (최대 5개) |
| `sellerStatusEnable` | | Boolean | 셀러 상태 필터 |
| `buyStatusEnable` | | Boolean | 바이어 상태 필터 |
| `statisticsDataQry` | | Object | 통계 데이터 조회 |
| `language` | | String | 언어 |
| `region` | ✅ | String | Region |

---

## 5. Query Sku&Spu basic information based on DW skuId

> DW(得物) skuId로 SKU/SPU 기본 정보 조회

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/intl-commodity/intl/sku/sku-basic-info/by-sku`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/intl-commodity/intl/sku/sku-basic-info/by-sku`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `skuIds` | | Array | DW skuId 리스트 |
| `sellerStatusEnable` | | Boolean | 셀러 상태 필터 |
| `buyStatusEnable` | | Boolean | 바이어 상태 필터 |
| `statisticsDataQry` | | Object | 통계 데이터 조회 |
| `language` | | String | 언어 |
| `region` | ✅ | String | Region |

---

## 6. Query Spu basic information (multilingual & support batch) by DW spuId

> DW spuId로 SPU 기본 정보 조회. 다국어 및 배치 지원.

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/intl-commodity/intl/spu/spu-basic-info/by-spu`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/intl-commodity/intl/spu/spu-basic-info/by-spu`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `spuIds` | ✅ | Array | DW spuId 리스트 (예: [3000000134]) |
| `sellerStatusEnable` | | Boolean | 셀러 비즈니스 라인 상품 상태 |
| `buyStatusEnable` | | Boolean | 바이어 비즈니스 라인 상품 상태 |
| `language` | | String | 언어 (기본값: en) |
| `region` | ✅ | String | Region |

---

## 7. Query SKU and SPU basic information based on seller's custom code (multilingual)

> 셀러 커스텀 코드로 SKU/SPU 기본 정보 조회. 다국어 지원.

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/intl-commodity/intl/sku/sku-basic-info/by-custom-code`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/intl-commodity/intl/sku/sku-basic-info/by-custom-code`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `customCode` | ✅ | String | SKU 차원 사용자 정의 상품 코드 |
| `sellerStatusEnable` | | Boolean | 셀러 상태 필터 (true: 필터링, false: 미필터링, 기본 false) |
| `buyStatusEnable` | | Boolean | 바이어 상태 필터 (true: 필터링, false: 미필터링, 기본 false) |
| `statisticsDataQry` | | Object | 통계 데이터 조회 |

---

## 8. Query Spu Information by Category ID - Batch

> 카테고리 ID로 SPU 정보 배치 조회

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/intl-commodity/intl/spu/spu-basic-info/by-categoryId`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/intl-commodity/intl/spu/spu-basic-info/by-categoryId`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `categoryIdList` | ✅ | Array | 카테고리 ID 리스트 (최대 20개, 예: [120019388]) |
| `region` | | String | Region (US, CN, HK, TW, MO, JP, KR, FR, IT, GB, ES, DE) |
| `language` | | String | 언어: zh, zh-TW, en, ja, ko, fr |
| `pageNum` | ✅ | Integer | 페이지 번호 (예: 1) |
| `pageSize` | | Integer | 페이지 사이즈 |

---

## 9. Query Spu Information by Brand ID - Batch

> 브랜드 ID로 SPU 정보 배치 조회

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/intl-commodity/intl/spu/spu-basic-info/by-brandId`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/intl-commodity/intl/spu/spu-basic-info/by-brandId`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `brandIdList` | ✅ | Array | 브랜드 ID 리스트 (최대 20개, 예: [120019388]) |
| `region` | | String | Region (US, CN, HK, TW, MO, JP, KR, FR, IT, GB, ES, DE) |
| `language` | | String | 언어: zh, zh-TW, en, ja, ko, fr |
| `pageNum` | ✅ | Integer | 페이지 번호 (예: 1) |
| `pageSize` | | Integer | 페이지 사이즈 |

---

## 10. Query Sku&Spu Information by globalSpuId - Batch

> globalSpuId로 SKU/SPU 정보 배치 조회

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/intl-commodity/intl/sku/sku-basic-info/by-global-spu`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/intl-commodity/intl/sku/sku-basic-info/by-global-spu`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `globalSpuIds` | ✅ | Array | 글로벌 SPU ID 리스트 (최대 5개) |
| `sellerStatusEnable` | | Boolean | 셀러 상태 필터 |
| `buyStatusEnable` | | Boolean | 바이어 상태 필터 |
| `statisticsDataQry` | | Object | 통계 데이터 조회 |
| `language` | | String | 언어: zh, zh-TW, en, ja, ko, fr |
| `region` | ✅ | String | Region |

---

## 11. Query Sku&Spu Information by globalSkuId - Batch

> globalSkuId로 SKU/SPU 정보 배치 조회

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/intl-commodity/intl/sku/sku-basic-info/by-global-sku`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/intl-commodity/intl/sku/sku-basic-info/by-global-sku`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `globalSkuIds` | | Array | 글로벌 SKU ID 리스트 (최대 100개, 예: [1200037452]) |
| `sellerStatusEnable` | | Boolean | 셀러 상태 필터 (예: false) |
| `buyStatusEnable` | | Boolean | 바이어 상태 필터 (예: false) |
| `statisticsDataQry` | | Object | 통계 데이터 조회 |
| `language` | | String | 언어: zh, zh-TW, en, ja, ko, fr |
| `region` | ✅ | String | Region |

---

## 12. Query Sku&Spu Information by Brand Official Item Number

> 브랜드 공식 품번(Article Number)으로 SKU/SPU 기본 정보 조회. 다국어 및 배치 지원.

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/intl-commodity/intl/sku/sku-basic-info/by-article-number`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/intl-commodity/intl/sku/sku-basic-info/by-article-number`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `articleNumber` | ✅ | String | 브랜드 공식 품번 (예: CZ3596-100) |
| `sellerStatusEnable` | | Boolean | 셀러 상태 필터 |
| `buyStatusEnable` | | Boolean | 바이어 상태 필터 |
| `language` | | String | 언어: zh, zh-TW, en, ja, ko, fr |
| `region` | ✅ | String | Region (US, CN, HK, TW, MO, JP, KR, FR, IT, GB, ES, DE) |

**Request 예시:**
```json
{
  "articleNumber": "363663-02",
  "sellerStatusEnable": false,
  "buyStatusEnable": false,
  "region": "US"
}
```

**Response 주요 구조:**
```json
{
  "trace_id": "...",
  "code": 200,
  "data": [{
    "spuInfo": {
      "globalSpuId": 3000000388,
      "dwSpuId": 1001019778,
      "brandId": 33,
      "brandName": "Li Ning",
      "articleNumber": "cxShoesSizeRule",
      "title": "상품명",
      "logoUrl": "https://cdn.poizon.com/...",
      "categoryId": 31,
      "categoryName": "Basketball Shoes",
      "level1CategoryId": 29,
      "level1CategoryName": "shoes",
      "level2CategoryId": 30,
      "level2CategoryName": "Sneakers",
      "fitId": 2,
      "status": 6
    },
    "region": "US",
    "globalSpuId": 3000000388,
    "skuInfoList": [{
      "globalSkuId": 3000000588,
      "dwSkuId": 6040943139,
      "regionSkuId": 602931884,
      "barCode": "",
      "extCode": "6040943139",
      "logoUrl": "https://cdn.poizon.com/...",
      "regionSalePvInfoList": [
        {"level": 1, "name": "Color", "value": "Advanced Black"},
        {"level": 2, "name": "Size", "value": "39", "sizeInfos": [
          {"sizeKey": "US", "value": "5.5"},
          {"sizeKey": "EU", "value": "39"},
          {"sizeKey": "UK", "value": "10"}
        ]},
        {"level": 3, "name": "Suit", "value": "套装1-1"}
      ]
    }]
  }]
}
```

---

## 13. Paginated Query by Category Name and Language

> 카테고리명과 언어로 페이지네이션 조회

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/intl-commodity/intl/category/page/by-name`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/intl-commodity/intl/category/page/by-name`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `categoryName` | ✅ | String | 카테고리명 |
| `level` | ✅ | Integer | 카테고리 레벨 |
| `language` | | String | 언어: zh, zh-TW, en, ja, ko, fr |
| `exactMatch` | | Boolean | 정확한 이름 매칭 (true: 정확 일치) |
| `pageSize` | ✅ | Integer | 페이지 사이즈 (기본 20, 최대 100) |
| `pageNum` | ✅ | Integer | 페이지 번호 (기본 1) |

---

## 14. Query Category Tree (Default Query All First-Level Categories)

> 카테고리 트리 조회. 기본값으로 모든 1차 카테고리 반환.

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/intl-commodity/intl/category/query/all`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/intl-commodity/intl/category/query/all`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `treeTag` | | Boolean | 카테고리 트리 표시 (true: 전체 트리, false: 1차만) |
| `language` | | String | 언어: zh, zh-TW, en, ja, ko, fr |

---

## 15. Query by Category ID and Language

> 카테고리 ID와 언어로 조회

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/intl-commodity/intl/category/query/by-id`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/intl-commodity/intl/category/query/by-id`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `ids` | | Array | 카테고리 ID 리스트 (최대 20개, 예: [12]) |
| `language` | | String | 언어: zh, zh-TW, en, ja, ko, fr |

---

## 16. Query by Brand ID and Language

> 브랜드 ID와 언어로 조회

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/intl-commodity/intl/brand/query/by-id`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/intl-commodity/intl/brand/query/by-id`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `brandIds` | ✅ | Array | 브랜드 ID 리스트 (최대 50개, 예: [2]) |
| `language` | | String | 언어: zh, zh-TW, en, ja, ko, fr |

---

## 17. Query Brand ID by Brand Name

> 브랜드명으로 브랜드 ID 조회

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/intl-commodity/intl/brand/page/by-name`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/intl-commodity/intl/brand/page/by-name`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `name` | | String | 브랜드명 |
| `language` | | String | 언어: zh, zh-TW, en, ja, ko, fr |
| `exactMatch` | | Boolean | 정확한 이름 매칭 (true: 정확 일치) |
| `pageSize` | ✅ | Integer | 페이지 사이즈 (최대 100) |
| `pageNum` | ✅ | Integer | 페이지 번호 |

---

## 18. Query Spu Basic Information by globalSpuId (Multilingual & Batch Support)

> globalSpuId로 SPU 기본 정보 조회. 다국어 및 배치 지원.

- **Endpoint:** `POST /dop/api/v1/pop/api/v1/intl-commodity/intl/spu/spu-basic-info/by-global-spu`
- **Full URL:** `https://open.poizon.com/dop/api/v1/pop/api/v1/intl-commodity/intl/spu/spu-basic-info/by-global-spu`

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `globalSpuIds` | ✅ | Array | 글로벌 SPU ID 리스트 (최대 100개, 예: [3000000134]) |
| `sellerStatusEnable` | | Boolean | 셀러 비즈니스 라인 상품 상태 |
| `buyStatusEnable` | | Boolean | 바이어 비즈니스 라인 상품 상태 |
| `language` | | String | 언어: zh, zh-TW, en, ja, ko, fr |
| `region` | ✅ | String | Region (US, CN, HK, TW, MO, JP, KR, FR, IT, GB, ES, DE) |

---

## 엔드포인트 URL 빠른 참조

| # | API명 (축약) | Endpoint Path |
|---|-------------|---------------|
| 1 | SPU by Article Number (fuzzy) | `.../intl/spu/spu-basic-info/by-article-number` |
| 2 | SPU by Brand ID (scroll) | `.../intl/spu/spu-basic-info/scroll-by-brandId` |
| 3 | SKU&SPU by barcode | `.../intl/sku/sku-basic-info/by-barcodes` |
| 4 | SKU&SPU by DW spuId | `.../intl/sku/sku-basic-info/by-spu` |
| 5 | SKU&SPU by DW skuId | `.../intl/sku/sku-basic-info/by-sku` |
| 6 | SPU by DW spuId (multilingual) | `.../intl/spu/spu-basic-info/by-spu` |
| 7 | SKU&SPU by custom code | `.../intl/sku/sku-basic-info/by-custom-code` |
| 8 | SPU by Category ID (batch) | `.../intl/spu/spu-basic-info/by-categoryId` |
| 9 | SPU by Brand ID (batch) | `.../intl/spu/spu-basic-info/by-brandId` |
| 10 | SKU&SPU by globalSpuId (batch) | `.../intl/sku/sku-basic-info/by-global-spu` |
| 11 | SKU&SPU by globalSkuId (batch) | `.../intl/sku/sku-basic-info/by-global-sku` |
| 12 | SKU&SPU by Brand Official Item# | `.../intl/sku/sku-basic-info/by-article-number` |
| 13 | Category by Name (paginated) | `.../intl/category/page/by-name` |
| 14 | Category Tree (all) | `.../intl/category/query/all` |
| 15 | Category by ID | `.../intl/category/query/by-id` |
| 16 | Brand by ID | `.../intl/brand/query/by-id` |
| 17 | Brand by Name | `.../intl/brand/page/by-name` |
| 18 | SPU by globalSpuId (multilingual) | `.../intl/spu/spu-basic-info/by-global-spu` |

---

## 참고: 지원 코드

**Region:** `US, CN, HK, TW, MO, JP, KR, FR, IT, GB, ES, DE`

**Language:** `zh, zh-TW, en, ja, ko, fr`

**Currency:** `CNY, USD, HKD, JPY, SGD, EUR, KRW`
