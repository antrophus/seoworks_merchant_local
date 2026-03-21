# POIZON Open API - Flutter 개발 통합 레퍼런스

> 출처: https://open.poizon.com
> 정리일: 2026-03-21
> 대상: Flutter 셀러 관리 앱 (Windows + Android)

---

## 빠른 참조

| 항목 | 값 |
|------|-----|
| Base URL | `https://open.poizon.com` |
| 기본 메서드 | POST (Bill/Bonded 일부 GET) |
| 인증 방식 | App Key + App Secret → MD5 서명 |
| 언어 코드 | `ko` (한국어), `en`, `zh`, `zh-TW`, `ja`, `fr` |
| 타임존 | `Asia/Seoul` |
| 총 API 수 | 약 100+ 엔드포인트 |

---

## 목차

1. [인증 & 서명](#1-인증--서명)
2. [공통 요청 파라미터](#2-공통-요청-파라미터)
3. [Dart 서명 구현 코드](#3-dart-서명-구현-코드)
4. [API 카테고리별 엔드포인트](#4-api-카테고리별-엔드포인트)
5. [셀러 앱 우선순위 워크플로우](#5-셀러-앱-우선순위-워크플로우)
6. [Flutter 연동 패키지 및 구조](#6-flutter-연동-패키지-및-구조)
7. [에러 처리](#7-에러-처리)

---

## 1. 인증 & 서명

### 사전 준비

1. [POIZON Open Platform](https://open.poizon.com) 로그인
2. Console → 앱 생성
3. **API Permission Package** 탭에서 필요한 권한 신청
4. **Application Info** 탭에서 `App Key` / `App Secret` 획득

### 서명(Sign) 생성 알고리즘

```
① 요청 파라미터 JSON에 app_key, timestamp(밀리초) 추가
② 비어있지 않은 키를 ASCII 오름차순 정렬
③ key=URLencode(value) 형식으로 연결 → stringA
④ stringA 끝에 appSecret 붙임 → stringSignTemp
⑤ MD5(stringSignTemp) → 대문자 변환 = sign 값
```

### 서명 주의사항

- 파라미터 이름은 **ASCII 오름차순** 정렬 (대소문자 구분)
- **빈 값** 파라미터는 서명에 포함하지 않음
- 값은 **UTF-8 URL-encode**
- JSON 배열 값은 콤마로 연결 후 인코딩
- `%20`은 `+`로 치환

---

## 2. 공통 요청 파라미터

모든 API 호출 시 포함해야 하는 파라미터:

| 파라미터 | 필수 | 타입 | 설명 |
|----------|:----:|------|------|
| `app_key` | ✅ | String | 앱 식별자 |
| `timestamp` | ✅ | Long | 현재 타임스탬프 (밀리초) |
| `sign` | ✅ | String | MD5 서명 |
| `language` | ✅ | String | 언어 코드 (`ko` 권장) |
| `timeZone` | ✅ | String | 타임존 (`Asia/Seoul` 권장) |
| `access_token` | ERP만 | String | ERP/ISV 연동 시에만 필요 |

---

## 3. Dart 서명 구현 코드

> 공식 문서에는 JS/Python/PHP/Java 예시만 있어 Dart 버전을 별도 구현 필요

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

class PoizonSigner {
  final String appKey;
  final String appSecret;

  PoizonSigner({required this.appKey, required this.appSecret});

  /// 요청 파라미터에 서명을 추가하여 반환
  Map<String, dynamic> sign(Map<String, dynamic> params) {
    final data = Map<String, dynamic>.from(params);
    data['app_key'] = appKey;
    data['timestamp'] = DateTime.now().millisecondsSinceEpoch;

    // 빈 값 제거
    data.removeWhere((key, value) => value == null || value.toString().isEmpty);

    // ASCII 오름차순 정렬 후 key=value 형식으로 연결
    final sortedKeys = data.keys.toList()..sort();
    final stringA = sortedKeys
        .map((key) => '$key=${Uri.encodeComponent(_valueToString(data[key]))}')
        .join('&');

    // appSecret 추가 후 MD5
    final stringSignTemp = '$stringA$appSecret';
    final sign = md5
        .convert(utf8.encode(stringSignTemp))
        .toString()
        .toUpperCase();

    data['sign'] = sign;
    return data;
  }

  /// 값 타입별 문자열 변환 (배열은 콤마 연결)
  String _valueToString(dynamic value) {
    if (value is List) {
      return value.map((e) => _valueToString(e)).join(',');
    } else if (value is Map) {
      // 중첩 객체는 JSON 직렬화
      return jsonEncode(value);
    }
    return value.toString();
  }
}
```

**필수 패키지:**
```yaml
dependencies:
  crypto: ^3.0.3  # pubspec.yaml에 추가
```

---

## 4. API 카테고리별 엔드포인트

### 4-1. Item (상품 조회) — 18개

Base Path: `/dop/api/v1/pop/api/v1/intl-commodity/`

| # | API명 | 엔드포인트 | 주요 파라미터 |
|---|-------|-----------|-------------|
| 1 | 품번으로 SPU 조회 | `POST .../intl/spu/spu-basic-info/by-article-number` | `articleNumber`, `region` |
| 2 | 브랜드 ID로 SPU 스크롤 조회 | `POST .../intl/spu/spu-basic-info/scroll-by-brandId` | `brandIdList`, `scrollId` |
| 3 | 바코드로 SKU/SPU 조회 | `POST .../intl/sku/sku-basic-info/by-barcodes` | `barcodes[]` (최대 100개) |
| 4 | DW spuId로 SKU/SPU 조회 | `POST .../intl/sku/sku-basic-info/by-spuid` | `spuId` |
| 5 | DW skuId로 SKU/SPU 조회 | `POST .../intl/sku/sku-basic-info/by-skuid` | `skuId` |
| 6 | globalSpuId로 다국어 배치 조회 | `POST .../intl/spu/spu-basic-info/by-globalSpuIds` | `globalSpuIds[]` |
| 7 | globalSkuId로 배치 조회 | `POST .../intl/sku/sku-basic-info/by-globalSkuIds` | `globalSkuIds[]` |
| 8 | 셀러 커스텀 코드로 조회 | `POST .../intl/sku/sku-basic-info/by-seller-custom-code` | `sellerCustomCode` |
| 9 | 카테고리 ID로 SPU 배치 조회 | `POST .../intl/spu/spu-basic-info/by-categoryIds` | `categoryIds[]` |
| 10 | 브랜드 ID로 SPU 배치 조회 | `POST .../intl/spu/spu-basic-info/by-brandIds` | `brandIds[]` |
| 11~12 | globalSpuId/globalSkuId 배치 | 별도 엔드포인트 | 배치 처리용 |
| 13 | 카테고리명+언어로 페이지 조회 | `POST .../intl/spu/page-by-category-name` | `categoryName`, `language` |
| 14 | 카테고리 트리 조회 | `POST .../intl/category/tree` | — |
| 15 | 카테고리 ID+언어로 조회 | `POST .../intl/category/by-categoryId` | `categoryId`, `language` |
| 16 | 브랜드 ID+언어로 조회 | `POST .../intl/brand/by-brandId` | `brandId`, `language` |
| 17 | 브랜드명으로 브랜드 ID 조회 | `POST .../intl/brand/by-brandName` | `brandName` |
| 18 | globalSpuId로 다국어 배치 (v2) | `POST .../intl/spu/spu-info/by-globalSpuIds` | `globalSpuIds[]` |

---

### 4-2. Listing & Inventory (리스팅/재고) — 19개

Base Path: `/dop/api/v1/pop/api/v1/`

#### 리스팅 등록

| 유형 | 엔드포인트 | 핵심 파라미터 |
|------|-----------|-------------|
| Ship-to-verify | `POST .../submit-bid/normal-autonomous-bidding` | `globalSkuId`, `price`, `quantity`, `countryCode` |
| Pre-sale | `POST .../submit-bid/pre-sell-autonomous-bidding` | 위 + `preAging`(유효 기간 일수) |
| Consignment | `POST .../submit-bid/consignment-autonomous-bidding` | `globalSkuId`, `price`, `quantity` |
| Direct | `POST .../submit-bid/direct-autonomous-bidding` | `globalSkuId`, `price`, `quantity` |
| 배치 자동 등록 | `POST .../submit-bid/auto-manual-bidding-batch` | `bidList[]` |

#### 리스팅 수정 / 취소

| API | 엔드포인트 |
|-----|-----------|
| Ship-to-verify 수정 | `POST .../update-bid/normal-autonomous-bidding` |
| Pre-sale 수정 | `POST .../update-bid/pre-sell-autonomous-bidding` |
| Consignment 수정 | `POST .../update-bid/consignment-autonomous-bidding` |
| Direct 수정 | `POST .../update-bid/direct-autonomous-bidding` |
| 리스팅 취소 | `POST .../cancel-bid` |

#### 리스팅 조회

| API | 엔드포인트 | 설명 |
|-----|-----------|------|
| 리스팅 목록 조회 | `POST .../query-bid/list` | 전체 리스팅 |
| Consignment 리스팅 조회 | `POST .../query-bid/consignment-list` | |
| 간편 리스팅 조회 | `POST .../query-bid/simple-list` | 경량 버전 |
| 최저가 추천 조회 | `POST .../recommend-bid` | 단건 |
| 최저가 추천 배치 | `POST .../recommend-bid/batch` | 배치 |
| 자동 입찰 제출 | `POST .../auto-bid/submit` | |
| 자동 입찰 목록 조회 | `POST .../auto-bid/list` | |
| Consignment 재고 조회 | `POST .../inventory/consignment` | |
| 약탈 입찰 복구 | `POST .../recovery-bid` | |

---

### 4-3. Consignment (위탁) — 9개

Base Path: `/dop/api/v1/pop/api/v1/consignment/`

| # | API명 | 메서드 | 설명 |
|---|-------|--------|------|
| 1 | 인바운드 주문 비동기 생성 | POST | 창고 입고 주문 생성 |
| 2 | 비동기 주문 생성 결과 조회 | POST | 생성 결과 확인 |
| 3 | 인바운드 주문 목록 조회 | POST | |
| 4 | 검수 상세 목록 조회 | POST | 검수 결과 확인 |
| 5 | 배송 정보 수정 | POST | |
| 6 | 인바운드 주문 취소 | POST | |
| 7 | 위탁 신청 생성 | POST | |
| 8 | 위탁 신청 목록 조회 | POST | |
| 9 | 위탁 신청 취소 | POST | |

---

### 4-4. Order (주문) — 7개

Base Path: `/dop/api/v1/pop/api/v1/order/`

| # | API명 | 메서드 | 핵심 파라미터 |
|---|-------|--------|-------------|
| 1 | 주문 확인 | POST | `orderId` |
| 2 | 주문 목록 조회 (유형별) | POST | `orderType`, `pageNum`, `pageSize` |
| 3 | 주문 목록 V2 | POST | 유형별 조회 개선 버전 |
| 4 | 주문 QC 결과 조회 | POST | `orderId` |
| 5 | 주문 서류 조회 | POST | `orderId` |
| 6 | 클라우드 인증 QR 코드 조회 | POST | `orderId` |
| 7 | 프라이버시 배송 라벨 조회 | POST | `orderId` |

---

### 4-5. Fulfillment (풀필먼트) — 8개

Base Path: `/dop/api/v1/pop/api/v1/fulfillment/`

| # | API명 | 메서드 | 설명 |
|---|-------|--------|------|
| 1 | 주문 배송 처리 | POST | 운송장 번호로 발송 처리 |
| 2 | 온라인 주문 운송장 정보 조회 | POST | 택배 라벨 정보 |
| 3 | 운송장 번호 수정 | POST | |
| 4 | 세관 신고 정보 배치 업로드 | POST | 크로스보더용 |
| 5 | 직접 수거 운송장 URL 조회 | POST | |
| 6 | 지원 운송사 목록 조회 | POST | |
| 7 | 위조방지 태그 연동 | POST | |
| 8 | 셀러 태그 정보 배치 조회 | POST | |

---

### 4-6. Bill (정산) — 5개

Base Path: `/dop/api/v1/pop/api/v1/bill/`
> ⚠️ **모두 GET 메서드**

| # | API명 | 엔드포인트 | 설명 |
|---|-------|-----------|------|
| 1 | 정산 인보이스 생성 | `GET .../generate` | `bill_no` → 다운로드 키 반환 |
| 2 | 정산 인보이스 다운로드 | `GET .../export` | `key` (1번 결과값) |
| 3 | 정산 주기 조정 목록 | `GET .../reconciliation-list` | 기간별 정산 내역 |
| 4 | 반품 주문 조회 | `POST .../return-orders` | |
| 5 | 실시간 정산 목록 | `GET .../real-time-list` | 실시간 정산 현황 |

---

### 4-7. Return (반품) — 8개

Base Path: `/dop/api/v1/pop/api/v1/return/`

| # | API명 | 설명 |
|---|-------|------|
| 1 | 반품 주소 확인 | 반품 수령 주소 조회 |
| 2 | 반품 예정 재고 조회 | 반품 처리 예정 재고 |
| 3 | 출고 주문 생성 | 반품 출고 처리 |
| 4 | 출고 주문 목록 조회 | |
| 5 | 출고 주문 상세 조회 | |
| 6 | 출고 영수증 서명 | 수령 확인 |
| 7 | 출고 픽업 날짜 정보 조회 | |
| 8 | 전체 주소 조회 | 등록된 주소 목록 |

---

### 4-8. Merchant (셀러 관리) — 3개

Base Path: `/dop/api/v1/pop/api/v1/merchant/`

| # | API명 | 설명 |
|---|-------|------|
| 1 | 공지사항 상세 조회 | 플랫폼 공지 |
| 2 | 셀러 SKU 코드 조회 | 커스텀 코드 확인 |
| 3 | 셀러 SKU 코드 수정 | 커스텀 코드 변경 |

---

### 4-9. Smart Listing (스마트 리스팅) — 22개

POIZON 자동 가격 최적화 기반 리스팅 관리

| 그룹 | API 수 | 설명 |
|------|--------|------|
| 상품 호스팅 (Hosted Data) | 8개 | 호스팅 데이터 CRUD + 리스팅/해제 |
| 신상품 등록 (New Product) | 6개 | 신상품 제출/조회/수정/삭제/심사 제출 |
| 상품 심사 (Item Review) | 3개 | 심사 가져오기/재신청/결과 |
| 스마트 리스팅 추천 | 2개 | 단건/배치 추천 |
| 자동 리스팅 | 2개 | 단건/배치 |
| 기회 재고 | 1개 | 판매 기회 재고 조회 |

---

### 4-10. Bonded (보세) — 18개

크로스보더 이커머스용 보세창고 관리

| 그룹 | API 수 | 설명 |
|------|--------|------|
| 보세 리스팅 관리 | 3개 | 추가/수정/취소 |
| 보세 조회 | 2개 | 리스팅 정보/자동화 |
| 브랜드 직접 입찰 | 2개 | 생성/수정 |
| 보세 주문 | 3개 | 목록/증분/배송 |
| 보세 재고 | 4개 | 최저가/판매중/SKU/창고 내 재고 |
| 보세 풀필먼트 | 2개 | 창고 정보/세관 조회 |
| 기타 | 2개 | 세관 확인/클라우드 인증 QR |

---

## 5. 셀러 앱 우선순위 워크플로우

### Phase 1 — 핵심 기능 (MVP)

```
[상품 조회]
품번/바코드 입력 → Item API → globalSkuId 획득
                                    ↓
[최저가 조회]
globalSkuId → recommend-bid → 현재 최저가 확인
                                    ↓
[리스팅 등록]
가격/수량 설정 → submit-bid → 리스팅 완료
                                    ↓
[주문 조회]
order/list → 신규 주문 확인 → 배송 처리
```

### Phase 2 — 운영 기능

```
[정산 관리]
bill/generate → bill/export → 정산서 다운로드

[반품 처리]
return/inventory → return/outbound-create → 반품 완료

[재고 관리]
inventory/consignment → 위탁 재고 현황 확인
```

### Phase 3 — 고급 기능

```
[스마트 리스팅]
Smart Listing API → POIZON 자동 가격 최적화

[보세 운영]
Bonded API → 크로스보더 재고/주문 관리
```

### 우선 구현 API 목록 (MVP)

| 우선순위 | API | 용도 |
|---------|-----|------|
| 🔴 필수 | Query SKU by barcode | 상품 검색 |
| 🔴 필수 | Query SKU by article number | 품번 검색 |
| 🔴 필수 | recommend-bid | 최저가 조회 |
| 🔴 필수 | submit-bid (Ship-to-verify) | 리스팅 등록 |
| 🔴 필수 | cancel-bid | 리스팅 취소 |
| 🔴 필수 | order list (V2) | 주문 조회 |
| 🔴 필수 | Ship Order | 발송 처리 |
| 🟡 중요 | update-bid | 리스팅 수정 |
| 🟡 중요 | bill/reconciliation-list | 정산 내역 |
| 🟡 중요 | return APIs | 반품 처리 |
| 🟢 선택 | Smart Listing APIs | 자동 가격 최적화 |
| 🟢 선택 | Bonded APIs | 보세 운영 |

---

## 6. Flutter 연동 패키지 및 구조

### 추가 필요 패키지

```yaml
dependencies:
  dio: ^5.4.3                    # HTTP 클라이언트
  crypto: ^3.0.3                 # MD5 서명 생성
  flutter_secure_storage: ^9.0.0 # App Key/Secret 안전 저장
  retry: ^3.1.2                  # API 재시도 로직
```

### 권장 레이어 구조

```
lib/core/
├── api/
│   ├── poizon_client.dart       # Dio 인스턴스 + 인터셉터
│   ├── poizon_signer.dart       # 서명 생성 (위 Dart 코드)
│   └── endpoints/
│       ├── item_api.dart        # 상품 조회
│       ├── listing_api.dart     # 리스팅 관리
│       ├── order_api.dart       # 주문 관리
│       ├── bill_api.dart        # 정산
│       └── return_api.dart      # 반품
├── models/
│   ├── sku_model.dart           # SKU/SPU 모델
│   ├── listing_model.dart       # 리스팅 모델
│   └── order_model.dart         # 주문 모델
└── sync/
    └── poizon_sync_service.dart # API → 로컬 DB 동기화
```

### API 클라이언트 기본 구조

```dart
class PoizonClient {
  final Dio _dio;
  final PoizonSigner _signer;

  static const _baseUrl = 'https://open.poizon.com';
  static const _language = 'ko';
  static const _timeZone = 'Asia/Seoul';

  PoizonClient({required String appKey, required String appSecret})
      : _signer = PoizonSigner(appKey: appKey, appSecret: appSecret),
        _dio = Dio(BaseOptions(baseUrl: _baseUrl));

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final signedBody = _signer.sign({
      ...body,
      'language': _language,
      'timeZone': _timeZone,
    });

    final response = await _dio.post(path, data: signedBody);
    return response.data;
  }
}
```

### 로컬 캐시 전략

```
API 호출 흐름:
1. 로컬 SQLite에서 캐시 데이터 즉시 반환 (오프라인 지원)
2. 백그라운드에서 POIZON API 호출
3. 변경사항 감지 → SQLite 업데이트
4. UI 리빌드 (Riverpod watch)

캐시 TTL 권장값:
- 상품 정보: 24시간
- 최저가 정보: 5분
- 주문 목록: 1분
- 정산 내역: 1시간
```

---

## 7. 에러 처리

### 공통 응답 구조

```json
{
  "code": 200,
  "data": { ... },
  "msg": ""
}
```

### 주요 에러 코드

| code | 의미 | 대응 방법 |
|------|------|----------|
| 200 | 성공 | — |
| 400 | 잘못된 요청 | 파라미터 확인 |
| 401 | 인증 실패 | App Key/Secret, 서명 로직 확인 |
| 403 | 권한 없음 | API Permission Package 신청 여부 확인 |
| 429 | 요청 한도 초과 | 재시도 로직 + Exponential backoff |
| 500 | 서버 오류 | 재시도 후 지속 시 POIZON 지원 문의 |

### Flutter 에러 처리 패턴

```dart
// retry 패키지 활용
final result = await retry(
  () => poizonClient.post('/dop/api/v1/...', body),
  retryIf: (e) => e is DioException &&
    (e.response?.statusCode == 429 || e.response?.statusCode == 500),
  maxAttempts: 3,
);
```

---

## 원본 문서 파일 목록

| 파일 | 내용 |
|------|------|
| `00-INDEX.md` | 전체 엔드포인트 인덱스 |
| `01-overview-and-authentication.md` | 인증/서명/워크플로우 |
| `02-item-api.md` | 상품 조회 API 상세 (18개) |
| `03-listing-inventory-api.md` | 리스팅/재고 API 상세 (19개) |
| `04-consignment-order-fulfillment-api.md` | 위탁/주문/풀필먼트 API 상세 |
| `05-bill-return-merchant-api.md` | 정산/반품/셀러 API 상세 |
| `06-smart-listing-bonded-api.md` | 스마트 리스팅/보세 API 상세 |
| `07-signature-samples-and-integration.md` | 언어별 서명 코드 샘플 |

---

*정리: Claude / 2026-03-21*
