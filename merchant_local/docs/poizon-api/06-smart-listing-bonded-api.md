# POIZON API - Smart Listing (스마트 리스팅)

> POIZON 자동 가격 설정 기반 스마트 리스팅 및 신상품 등록 API

---

## 엔드포인트 목록

### 상품 호스팅 (Hosted Data)

| # | API명 | 메서드 | 설명 |
|---|--------|--------|------|
| 1 | Add Hosted Data | POST | 호스팅 데이터 추가 |
| 2 | Query Hosted Data | POST | 호스팅 데이터 조회 |
| 3 | Update Hosted Data | POST | 호스팅 데이터 수정 |
| 4 | Hosted-Query Unmatched Product List | POST | 매칭되지 않은 상품 목록 조회 |
| 5 | Hosted-Query Product Recommended Matching List | POST | 상품 추천 매칭 목록 조회 |
| 6 | Hosted-Confirm SKU Matched | POST | SKU 매칭 확인 |
| 7 | 商品托管-上架 (Hosted - List) | POST | 호스팅 상품 리스팅(상가) |
| 8 | 商品托管-下架 (Hosted - Delist) | POST | 호스팅 상품 리스팅 해제(하가) |

### 신상품 등록 (New Product)

| # | API명 | 메서드 | 설명 |
|---|--------|--------|------|
| 9 | Submit New Product | POST | 신상품 제출 |
| 10 | Get New Product Details | POST | 신상품 상세 조회 |
| 11 | Get New Product List | POST | 신상품 목록 조회 |
| 12 | Submit New Product for Review | POST | 신상품 심사 제출 |
| 13 | Delete New Product Draft | POST | 신상품 초안 삭제 |
| 14 | Modify New Item | POST | 신상품 수정 |

### 상품 심사 (Item Review)

| # | API명 | 메서드 | 설명 |
|---|--------|--------|------|
| 15 | Item Review-Import Products | POST | 상품 심사 - 상품 가져오기 |
| 16 | Item Review-Revise&Reapply | POST | 상품 심사 - 수정 및 재신청 |
| 17 | Item Review-Results | POST | 상품 심사 - 결과 조회 |

### 리스팅 & 재고

| # | API명 | 메서드 | 설명 |
|---|--------|--------|------|
| 18 | Smart Listing Recommendations - Batch | POST | 스마트 리스팅 추천 배치 |
| 19 | Auto-Manual Listing | POST | 자동-수동 리스팅 |
| 20 | Auto-Manual Listing - Batch | POST | 자동-수동 리스팅 배치 |
| 21 | View Goods Opportunity Inventory Details | POST | 상품 기회 재고 상세 조회 |
| 22 | Product Opportunity Inventory - Batch Creation | POST | 상품 기회 재고 배치 생성 |

### Item Review-Revise&Reapply 상세 파라미터

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `categoryL1Id` | String | 1차 카테고리 ID |
| `categoryL1` | String | 1차 카테고리명 |
| `brandId` | String | 브랜드 ID |
| `brandName` | String | 브랜드명 |
| `spuName` | String | 상품명 |
| `designerId` | String | 품번 |
| `barcode` | Long | 바코드 |
| `currency` | String | 통화 (CNY, USD, HKD, JPY, SGD, EUR, KRW) |
| `images` | List\<String\> | 상품 이미지 URL 목록 |
| `fixId` | Integer | 적용 대상 ID |
| `fixName` | String | 적용 대상명 |
| `sizeType` | String | 사이즈 유형 |
| `size` | String | 사이즈 |
| `specification` | String | 스펙 |
| `color` | String | 색상 |
| `inventory` | Long | 현재 재고 |
| `deliverable30Day` | Long | 30일 내 배송 가능 수량 |
| `sharePercentage` | Float | Dewu 공유 재고 비율 |
| `quantity30Day` | Long | 30일 내 입고 가능 수량 |
| `inventoryRegion` | String | 재고 지역 |
| `merchantSpuId` | String | 셀러 SPU ID |
| `merchantSkuId` | String | 셀러 SKU ID |
| `externalLink` | String | 외부 링크 |
| `id` | Long | 상품 ID |

---

# POIZON API - Bonded (보세)

> 보세 창고 기반 크로스보더 이커머스 API

---

## 엔드포인트 목록

### 리스팅 관리

| # | API명 | 메서드 | 설명 |
|---|--------|--------|------|
| 1 | Add Listing [Bonded Warehouse] | POST | 보세 창고 리스팅 추가 |
| 2 | Update Listing [Bonded Warehouse] | POST | 보세 창고 리스팅 수정 |
| 3 | Cancel Listing [Bonded Warehouse] | POST | 보세 창고 리스팅 취소 |
| 4 | Get Merchant Listing Information [Bonded Warehouse] | POST | 셀러 리스팅 정보 조회 [보세] |
| 5 | Automate Listing | POST | 자동 리스팅 |
| 6 | Bonded - Create Brand Direct Bidding | POST | 보세 - 브랜드 직접 입찰 생성 |
| 7 | Bonded - Update Brand Direct Bidding | POST | 보세 - 브랜드 직접 입찰 수정 |

### 주문 관리

| # | API명 | 메서드 | 설명 |
|---|--------|--------|------|
| 8 | Query Order List [Bonded Warehouse] | GET | 보세 창고 주문 목록 조회 |
| 9 | Incremental Order Retrieval [Bonded Warehouse] | GET | 보세 창고 증분 주문 조회 |
| 10 | Bonded - Order Delivery | POST | 보세 주문 배송 처리 |

### 가격 & 재고

| # | API명 | 메서드 | 설명 |
|---|--------|--------|------|
| 11 | Get Platform's Lowest Price for SKU [Cross-border-bonded Warehouse] | POST | 크로스보더 보세 SKU 플랫폼 최저가 조회 |
| 12 | Get Real-time Inventory of Seller's On-sale SKU [Bonded Warehouse] | GET | 보세 판매 중 SKU 실시간 재고 조회 |
| 13 | Bonded - Query SKU Inventory Details | POST | 보세 SKU 재고 상세 조회 |
| 14 | Bonded - Query In-Warehouse Inventory Details | POST | 보세 창고 내 재고 상세 조회 |

### 기타

| # | API명 | 메서드 | 설명 |
|---|--------|--------|------|
| 15 | Query Bonded Fulfillment Warehouse Information | POST | 보세 풀필먼트 창고 정보 조회 |
| 16 | Bonded Warehouse Order Customs Declaration Information Query | POST | 보세 주문 통관 신고 정보 조회 |
| 17 | Third-Party Merchant Acknowledgment for Order Customs Declaration | POST | 주문 통관 신고 서드파티 셀러 확인 |
| 18 | Get Cloud Authentication Task QR Code | POST | 클라우드 인증 작업 QR 코드 조회 |
