# POIZON Open Platform API Documentation

> 출처: https://open.poizon.com/doc/list/documentationDetail/33
> 작성일: 2026-03-19

---

## 1. 개요 (API Fact Sheet)

POIZON Open Platform은 셀러를 위한 두 가지 API 통합 방식을 제공합니다.

### 통합 방식

| 방식 | 설명 |
|------|------|
| **Seller Integration with POIZON** | 셀러가 자체 ERP 시스템을 통해 상품, 재고, 주문 등의 데이터를 POIZON 플랫폼에 연동 |
| **POIZON Integration with Sellers** | POIZON이 셀러의 시스템(Shopify, WooCommerce, BigCommerce 등)에 API로 연결하여 데이터 동기화 |

### 리스팅 유형

| 유형 | 설명 |
|------|------|
| **Manual Listing** | 셀러가 시장 상황과 자체 전략에 따라 가격 직접 설정 |
| **Smart Listing** | POIZON이 플랫폼 시장 데이터 기반으로 자동 최적 가격 설정 |

### 풀필먼트 유형

| 유형 | 설명 |
|------|------|
| **Ship-to-verify** | 셀러가 자체 창고에 재고를 보관하고 주문 시 직접 발송 |
| **Consignment** | POIZON 창고에 상품 보관, POIZON이 보관 및 발송 관리 |
| **Pre-sale** | 상품 입고 전 선판매, 입고 후 발송 |
| **Bonded** | 보세 구역에 상품 보관, POIZON이 통관 및 배송 관리 (크로스보더 이커머스용) |

---

## 2. 인증 (Authentication)

### Step 1: 앱 생성
1. POIZON Open Platform 계정 로그인
2. Console → 앱 생성
3. 필수 정보 입력 후 제출

### Step 2: API 권한 신청
- 앱 상세 페이지 → "API Permission Package" 탭
- 필요한 API 권한 패키지 신청

### Step 3: App Key & App Secret 획득
- 앱 상세 페이지 → "Application Info" 탭
- App Key 및 App Secret 복사

### Step 4: 서명(Signature) 생성

#### 서명 생성 규칙

1. 모든 전송 데이터를 JSON 객체로 설정
2. `appKey`와 `timestamp`(현재 밀리초 타임스탬프)를 JSON 객체에 추가
3. 비어있지 않은 키의 파라미터를 ASCII 값 기준 오름차순 정렬
4. URL key-value 형식(`a=a&b=b…`)으로 `stringA` 생성
5. `stringA` 끝에 `appSecret`을 붙여 `stringSignTemp` 생성
6. `stringSignTemp`에 MD5(32-bit) 해시 → 대문자 변환 = **sign 값**

#### 주의사항
- 파라미터 이름은 ASCII 오름차순 정렬
- 빈 값은 서명에 포함하지 않음
- 파라미터 이름/값은 대소문자 구분
- 값은 URL-encode (UTF-8)
- JSON 배열 값은 콤마로 연결
- key/value 연결 시 `URLEncoder.encode()` 사용

#### 서명 예시

**요청 파라미터:**
```json
{
  "app_key": "4d1715e032c44b709ef4954ef13e0950",
  "appoint_no": "A14343543654",
  "sku_list": [
    {
      "spu_id": 81293,
      "sku_id": 487752589,
      "bar_code": "487752589",
      "article_number": "wucaishi",
      "appoint_num": 10,
      "brand_id": 10444,
      "category_id": 46
    }
  ],
  "timestamp": 1603354338917
}
```

**서명 결과:** `A0BC221AB4EF5190EFD7D593566C67472`

### 공통 요청 파라미터 (General Parameters)

| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `app_key` | ✅ | String | Application identifier |
| `access_token` | ERP/ISV만 | String | Request token (ERP/ISV 연동 시 필수) |
| `timestamp` | ✅ | Long | 현재 타임스탬프 (밀리초) |
| `sign` | ✅ | String | 서명 문자열 |
| `language` | ✅ | String | 언어: zh, zh-TW, en, ja, ko, fr |
| `timeZone` | ✅ | String | 타임존 (예: Asia/Shanghai) |

---

## 3. API 워크플로우 (API Introduction)

### 기본 흐름

```
Step 1: 상품 조회 (globalSkuId 획득)
    → /intl-commodity
    ↓
Step 2: 리스팅 추천 조회
    → /recommend-bid
    ↓
Step 3: 리스팅 등록/수정/취소
    → /submit-bid
    ↓
Step 4: 주문 배송 관리
    → /order/delivery
    ↓
Step 5: 정산 관리
    → /bill
```

### Step 1: 상품 조회 방법

**방법 A - 브랜드 공식 품번으로 조회:**
- `Query Sku&Spu Information by Brand Official Item Number` API 사용
- 예: Nike Air Force 1의 품번 "FJ4170-004"로 검색

**방법 B - 브랜드명으로 조회:**
1. `Query Brand ID by Brand Name` → 브랜드 ID 획득
2. `Query SPU Information by Brand ID` → SPU 정보 획득
3. `Query SKU Information by globalSpuId` → globalSkuId 획득
