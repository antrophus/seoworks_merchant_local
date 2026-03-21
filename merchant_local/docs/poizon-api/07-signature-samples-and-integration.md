# POIZON API - Signature Code Samples (서명 코드 예시)

> 각 언어별 서명 생성 코드

---

## Node.js

```javascript
/**
 * Signature algorithm
 */
private sign(data = {}) {
  data.timestamp = Date.now()
  data.app_key = DE_WU_OPEN.dewuAppkey

  let paramsStr = Object.keys(data)
    .sort()
    .map(key => `${key}=${encodeURIComponent(data[key])}`)
    .join('&') + `${DE_WU_OPEN.dewuAppsecret}`

  paramsStr = paramsStr.replace(/%20/gi, '+')
  data.sign = CryptoUtil.md5(paramsStr).toUpperCase()
  return data
}
```

## Python

```python
def calculate_sign(self, key_dict: dict):
    sort_key_list = sorted(list(key_dict.keys()))
    new_str = ""
    prams = {}
    for key in sort_key_list:
        value = key_dict.get(key)
        prams[key] = getStr(value)
        valueStr = quote_plus(prams[key], 'utf-8')
        new_str = new_str + key + "=" + valueStr + "&"

    new_key = new_str[:-1] + self.app_secret
    m = hashlib.md5()
    m.update(new_key.encode('UTF-8'))
    sign = m.hexdigest().upper()
    return sign, new_str[:-1]


def getStr(obj, isSub=False):
    valueStr = ''
    if isinstance(obj, (list, tuple)):
        if isinstance(obj[0], str):
            return ','.join(x for x in obj)
        valueStr = ','.join(getStr(x, True) for x in obj)
        if isSub:
            valueStr = '[' + valueStr + ']'
    elif isinstance(obj, dict):
        valueStr += "{"
        for subObj in sorted(list(obj.keys())):
            valueStr += "\"" + subObj + "\":"
            valueStr += getStr(obj.get(subObj), True) + ","
        valueStr = valueStr[:-1] + "}"
    elif isinstance(obj, set):
        obj = sorted(list(obj))
        return getStr(obj, True)
    elif isinstance(obj, str) and isSub:
        valueStr = "\"" + obj + "\""
    else:
        valueStr = str(obj)
    return valueStr
```

## PHP

```php
/**
 * Generate signature
 * @param $paramArr
 * @return string
 */
private function createSign($paramArr) {
    ksort($paramArr);
    foreach($paramArr as $key => $val) {
        if(is_array($val)) {
            $paramArr[$key] = json_encode($val, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        }
    }
    $sign_str = http_build_query($paramArr, NULL, '&');
    $sign_str .= $this->appSecret;
    return strtoupper(md5($sign_str));
}
```

## Java

```java
public class Signer {
    public String createSign(Map<String, Object> params, String secret) {
        if (params.containsKey("secret")) {
            params.remove("secret");
        }
        String paramsString = JsonUtil.obj2String(params);
        TreeMap<String, String> treeMap = jsonToMap(paramsString);
        String sign = getSign(treeMap, secret);
        return sign;
    }

    public String getSign(TreeMap<String, String> reqParams, String secret) {
        String sortedKvStr = reqParams.entrySet().stream().map(entry -> {
            try {
                return URLEncoder.encode(String.valueOf(entry.getKey()), "UTF-8")
                    + "=" + URLEncoder.encode(String.valueOf(entry.getValue()), "UTF-8") + "&";
            } catch (UnsupportedEncodingException e) {
                throw new RuntimeException(e);
            }
        }).reduce("", String::concat);

        sortedKvStr = sortedKvStr.substring(0, sortedKvStr.length() - 1) + secret;
        String sign = MD5Util.getMD5Str(sortedKvStr).toUpperCase();
        return sign;
    }
}
```

---

## POIZON Integration with Sellers (스마트 리스팅 - 셀러 시스템 연동)

POIZON이 셀러 시스템에 연동할 때 셀러가 제공해야 하는 API 및 필수 필드:

### 셀러가 제공해야 하는 API

| API | 설명 |
|-----|------|
| API - Overall Commodity Information | 전체 상품 정보 |
| API - Updated Commodity Information | 변경된 상품 정보 |
| API - Order | 주문 정보 |

### 셀러가 제공해야 하는 필수 필드

| 필드 | 설명 | 비고 |
|------|------|------|
| `spuId` | 색상 기반 상품 ID | |
| `skuId` | 사이즈+색상 기반 상품 ID | |
| `brandName` | 브랜드명 | |
| `designerId` | 브랜드 스타일/제조업체 ID | |
| `gender` | 대상: women, men, unisex 등 | |
| `category` | 카테고리: shoes, apparel, bags 등 | |
| `season` | 시즌: FW24, SS24 등 | |
| `size` | 사이즈 | |
| `sizeType` | 사이즈 시스템: EU, UK, US, FR, JP 등 | 신발/의류만 필수 |
| `images` | 상품 이미지 URL | |
| `stock` | 재고 수량 | |

### 가격 필드 (4가지 중 최소 1개 필수)

| 필드 | 설명 |
|------|------|
| `retailPrice` | 소매가 (VAT 포함, 할인 없음) |
| `dutyFreePrice` | 소매가 (VAT 미포함, 할인 없음) |
| `purchasePrice` | 공급가 (VAT 미포함, 할인 적용) |
| `taxPurchasePrice` | 공급가 (VAT 포함, 할인 적용) |
