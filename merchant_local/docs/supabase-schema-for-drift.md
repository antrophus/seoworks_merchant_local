# Supabase → Drift(SQLite) DB 이식 가이드

> 실제 운영 DB에서 2026-03-22 추출한 스키마 기준
> 백업 데이터 위치: `d:\dev\2026\my_project\merchant_manage\backups\`

---

## 1. 현재 DB 통계

| 테이블 | 행 수 | 비고 |
|--------|------:|------|
| brands | 198 | 마스터 |
| sources | 39 | 마스터 |
| products | 371 | 마스터 |
| size_charts | 372 | 마스터 |
| items | 1,197 | 핵심 |
| purchases | 1,196 | 1:1 (items) |
| sales | 1,195 | 1:1 (items) |
| sale_adjustments | 1 | sales FK |
| status_logs | 993 | items FK |
| inspection_rejections | 11 | items FK |
| repairs | 3 | items FK |
| shipments | 921 | items FK |
| supplier_returns | 0 | items FK |
| order_cancellations | 0 | items FK |
| sample_usages | 0 | items FK |
| platform_fee_rules | 9 | 설정 |
| poizon_sync_logs | 0 | 로그 |
| bot_review_queue | 0 | 봇 전용 |

---

## 2. ENUM → TEXT 매핑

PostgreSQL의 ENUM 타입은 SQLite에서 TEXT + CHECK 제약으로 대체한다.

### item_status
```
ORDER_PLACED, ORDER_CANCELLED, OFFICE_STOCK, OUTGOING, IN_INSPECTION,
LISTED, SOLD, SETTLED, RETURNING, DEFECT_FOR_SALE, DEFECT_SOLD,
DEFECT_SETTLED, SUPPLIER_RETURN, DISPOSED, SAMPLE, DEFECT_HELD, REPAIRING
```

### payment_method
```
CORPORATE_CARD, PERSONAL_CARD, CASH, TRANSFER
```

### sale_platform
```
KREAM, POIZON, SOLDOUT, DIRECT, OTHER
```

### size_target
```
MEN, WOMEN, KIDS
```

---

## 3. 테이블 정의 (PostgreSQL → Drift 변환 참고)

### 타입 변환 규칙

| PostgreSQL | Drift (SQLite) | 비고 |
|---|---|---|
| `uuid` | `TextColumn` | UUID 문자열 그대로 저장 |
| `text` | `TextColumn` | |
| `bool` | `BoolColumn` | |
| `int4` | `IntColumn` | |
| `numeric(12,0)` | `IntColumn` | 정수로 충분 (원 단위 금액) |
| `numeric(5,4)` | `RealColumn` | 소수점 필요 (수수료율) |
| `numeric` (precision 없음) | `RealColumn` | size_charts.kr |
| `date` | `TextColumn` | ISO 8601 "YYYY-MM-DD" |
| `timestamptz` | `TextColumn` | ISO 8601 "YYYY-MM-DDTHH:mm:ss.sssZ" |
| `_text` (TEXT[]) | `TextColumn` | JSON 배열 문자열로 저장 |
| `jsonb` | `TextColumn` | JSON 문자열로 저장 |
| `gen_random_uuid()` | 앱 코드에서 `uuid` 패키지로 생성 | |
| `now()` | 앱 코드에서 `DateTime.now().toIso8601String()` | |

---

### 3-1. brands
```
id          TEXT PRIMARY KEY (uuid)
name        TEXT NOT NULL, UNIQUE
code        TEXT NULL, UNIQUE
created_at  TEXT NULL (timestamptz, default: now)
```

### 3-2. sources
```
id          TEXT PRIMARY KEY (uuid)
name        TEXT NOT NULL, UNIQUE
type        TEXT NULL
url         TEXT NULL
created_at  TEXT NULL (timestamptz, default: now)
```

### 3-3. products
```
id            TEXT PRIMARY KEY (uuid)
brand_id      TEXT NULL → FK brands(id)
model_code    TEXT NOT NULL, UNIQUE
model_name    TEXT NOT NULL
gender        TEXT NULL
category      TEXT NULL
image_url     TEXT NULL
poizon_spu_id TEXT NULL, UNIQUE
created_at    TEXT NULL (timestamptz, default: now)
```

### 3-4. size_charts
```
id          TEXT PRIMARY KEY (uuid)
brand       TEXT NOT NULL
target      TEXT NOT NULL (MEN/WOMEN/KIDS)
kr          REAL NOT NULL
eu          TEXT NULL
us_m        TEXT NULL
us_w        TEXT NULL
us          TEXT NULL
uk          TEXT NULL
jp          TEXT NULL
created_at  TEXT NULL (timestamptz, default: now)

UNIQUE(brand, target, kr)
```

### 3-5. items ⭐ 핵심 테이블
```
id              TEXT PRIMARY KEY (uuid)
product_id      TEXT NOT NULL → FK products(id)
sku             TEXT NOT NULL, UNIQUE
size_kr         TEXT NOT NULL
size_eu         TEXT NULL
size_us         TEXT NULL
size_etc        TEXT NULL
barcode         TEXT NULL
tracking_number TEXT NULL
is_personal     INTEGER NOT NULL DEFAULT 0 (boolean)
current_status  TEXT NOT NULL DEFAULT 'OFFICE_STOCK' (item_status enum)
location        TEXT NULL
defect_note     TEXT NULL
note            TEXT NULL
poizon_sku_id   TEXT NULL
created_at      TEXT NULL (timestamptz, default: now)
updated_at      TEXT NULL (timestamptz, default: now)
```

### 3-6. purchases (items와 1:1)
```
id              TEXT PRIMARY KEY (uuid)
item_id         TEXT NOT NULL, UNIQUE → FK items(id)
purchase_date   TEXT NULL (date: YYYY-MM-DD)
purchase_price  INTEGER NULL (numeric(12,0))
payment_method  TEXT NOT NULL DEFAULT 'PERSONAL_CARD' (payment_method enum)
source_id       TEXT NULL → FK sources(id)
vat_refundable  REAL NULL (numeric(12,2))
receipt_url     TEXT NULL
memo            TEXT NULL
created_at      TEXT NULL (timestamptz, default: now)
```

### 3-7. sales (items와 1:1)
```
id                TEXT PRIMARY KEY (uuid)
item_id           TEXT NOT NULL, UNIQUE → FK items(id)
sale_date         TEXT NULL (date)
platform          TEXT NOT NULL (sale_platform enum)
platform_option   TEXT NULL
listed_price      INTEGER NULL (numeric(12,0))
sell_price        INTEGER NULL (numeric(12,0))
platform_fee_rate REAL NULL (numeric(5,4))
platform_fee      INTEGER NULL (numeric(12,0))
settlement_amount INTEGER NULL (numeric(12,0))
adjustment_total  INTEGER NOT NULL DEFAULT 0 (numeric(12,0))
outgoing_date     TEXT NULL (date)
shipment_deadline TEXT NULL (timestamptz)
tracking_number   TEXT NULL
settled_at        TEXT NULL (date)
memo              TEXT NULL
poizon_order_id   TEXT NULL, UNIQUE
data_source       TEXT NULL DEFAULT 'manual'
created_at        TEXT NULL (timestamptz, default: now)
```

### 3-8. sale_adjustments
```
id          TEXT PRIMARY KEY (uuid)
sale_id     TEXT NOT NULL → FK sales(id) ON DELETE CASCADE
type        TEXT NOT NULL (COUPON/PENALTY/STORAGE_FEE/OTHER)
amount      INTEGER NOT NULL (numeric(12,0))
memo        TEXT NULL
created_at  TEXT NULL (timestamptz, default: now)
```

### 3-9. status_logs
```
id          TEXT PRIMARY KEY (uuid)
item_id     TEXT NOT NULL → FK items(id)
old_status  TEXT NULL (item_status enum)
new_status  TEXT NOT NULL (item_status enum)
note        TEXT NULL
changed_at  TEXT NULL (timestamptz, default: now)
```

### 3-10. inspection_rejections
```
id               TEXT PRIMARY KEY (uuid)
item_id          TEXT NOT NULL → FK items(id)
return_seq       INTEGER NOT NULL
rejected_at      TEXT NOT NULL (date)
reason           TEXT NULL
photo_urls       TEXT NULL (JSON 배열 문자열)
platform         TEXT NULL (sale_platform enum)
memo             TEXT NULL
defect_type      TEXT NULL (DEFECT_SALE/DEFECT_HELD/DEFECT_RETURN)
discount_amount  INTEGER NULL (numeric(12,0))
created_at       TEXT NULL (timestamptz, default: now)

UNIQUE(item_id, return_seq)
```

### 3-11. repairs
```
id           TEXT PRIMARY KEY (uuid)
item_id      TEXT NOT NULL → FK items(id)
started_at   TEXT NOT NULL DEFAULT CURRENT_DATE (date)
completed_at TEXT NULL (date)
repair_cost  INTEGER NULL (numeric(12,0))
repair_note  TEXT NULL
outcome      TEXT NULL (RELISTED/SUPPLIER_RETURN/DISPOSED/PERSONAL)
created_at   TEXT NOT NULL (timestamptz, default: now)
```

### 3-12. shipments
```
id              TEXT PRIMARY KEY (uuid)
item_id         TEXT NOT NULL → FK items(id)
seq             INTEGER NOT NULL
tracking_number TEXT NOT NULL
outgoing_date   TEXT NULL (date)
platform        TEXT NULL (sale_platform enum)
memo            TEXT NULL
created_at      TEXT NULL (timestamptz, default: now)

UNIQUE(item_id, seq)
```

### 3-13. supplier_returns
```
id          TEXT PRIMARY KEY (uuid)
item_id     TEXT NOT NULL, UNIQUE → FK items(id)
returned_at TEXT NOT NULL (date)
reason      TEXT NULL
memo        TEXT NULL
created_at  TEXT NULL (timestamptz, default: now)
```

### 3-14. order_cancellations
```
id           TEXT PRIMARY KEY (uuid)
item_id      TEXT NOT NULL, UNIQUE → FK items(id)
cancelled_at TEXT NOT NULL (date)
reason       TEXT NULL
memo         TEXT NULL
created_at   TEXT NULL (timestamptz, default: now)
```

### 3-15. sample_usages
```
id         TEXT PRIMARY KEY (uuid)
item_id    TEXT NOT NULL, UNIQUE → FK items(id)
purpose    TEXT NOT NULL
used_at    TEXT NULL (date)
memo       TEXT NULL
created_at TEXT NULL (timestamptz, default: now)
```

### 3-16. platform_fee_rules (설정 테이블)
```
id         TEXT PRIMARY KEY (uuid)
platform   TEXT NOT NULL
category   TEXT NOT NULL DEFAULT 'default'
fee_rate   REAL NOT NULL (numeric(5,4))
min_fee    INTEGER NOT NULL DEFAULT 0
max_fee    INTEGER NULL
note       TEXT NULL
updated_at TEXT NULL (timestamptz, default: now)

UNIQUE(platform, category)
```

### 3-17. poizon_sync_logs
```
id           TEXT PRIMARY KEY (uuid)
sync_type    TEXT NOT NULL (orders/inspection/settlement/backfill/return/listing)
window_start TEXT NULL (timestamptz)
window_end   TEXT NULL (timestamptz)
synced_at    TEXT NULL (timestamptz, default: now)
records_in   INTEGER NULL DEFAULT 0
records_ok   INTEGER NULL DEFAULT 0
records_skip INTEGER NULL DEFAULT 0
status       TEXT NOT NULL (success/partial/error)
error_msg    TEXT NULL
```

### 3-18. bot_review_queue
```
id              TEXT PRIMARY KEY (uuid)
item_id         TEXT NOT NULL → FK items(id)
sale_id         TEXT NULL → FK sales(id)
change_type     TEXT NOT NULL (TRACKING_UPDATE/SELL_PRICE_UPDATE/ADJUSTMENT_ADD/SETTLEMENT_UPDATE)
proposed_data   TEXT NOT NULL (JSON 문자열)
snapshot_status TEXT NULL
snapshot_at     TEXT NULL (timestamptz)
shadow_queue_id TEXT NULL
status          TEXT NOT NULL DEFAULT 'PENDING' (PENDING/APPROVED/REJECTED/CONFLICT)
conflict_reason TEXT NULL
reviewed_by     TEXT NULL
reviewed_at     TEXT NULL (timestamptz)
created_at      TEXT NULL (timestamptz, default: now)
```

---

## 4. Foreign Key 관계도

```
brands ──┐
         └──< products.brand_id
                  │
sources ──┐      │
          │      └──< items.product_id
          │                │
          │                ├──< purchases.item_id (1:1 UNIQUE)
          │                │         └── purchases.source_id ──> sources
          │                │
          │                ├──< sales.item_id (1:1 UNIQUE)
          │                │         └──< sale_adjustments.sale_id (CASCADE DELETE)
          │                │
          │                ├──< status_logs.item_id (N:1)
          │                ├──< inspection_rejections.item_id (N:1)
          │                ├──< repairs.item_id (N:1)
          │                ├──< shipments.item_id (N:1)
          │                ├──< supplier_returns.item_id (1:1 UNIQUE)
          │                ├──< order_cancellations.item_id (1:1 UNIQUE)
          │                ├──< sample_usages.item_id (1:1 UNIQUE)
          │                └──< bot_review_queue.item_id (N:1)
          │                          └── bot_review_queue.sale_id ──> sales
          │
platform_fee_rules (독립, FK 없음)
poizon_sync_logs (독립, FK 없음)
size_charts (독립, FK 없음 — brand는 TEXT, brands 테이블과 FK 없음)
```

---

## 5. 비즈니스 로직 (트리거 → 앱 코드로 이식)

PostgreSQL 트리거는 SQLite에서 직접 지원이 제한적이므로, **Drift의 DAO나 Service 레이어에서 구현**한다.

### 5-1. calculate_sale_settlement (판매 정산 계산)
- **트리거 시점**: sales INSERT/UPDATE 전 (BEFORE)
- **로직**:
  ```
  IF sell_price IS NOT NULL:
    IF platform == 'POIZON':
      1. items → products 조인으로 category 조회
      2. platform_fee_rules에서 (platform='POIZON', category) 매칭
      3. 없으면 category='default' 폴백
      4. 그래도 없으면 하드코딩: rate=0.10, min=15000, max=45000
      5. fee = CLAMP(sell_price × fee_rate, min_fee, max_fee)
      6. platform_fee = fee
      7. platform_fee_rate = fee / sell_price
      8. settlement_amount = sell_price - fee + adjustment_total

    IF platform IN ('DIRECT', 'OTHER'):
      fee = 0, rate = 0
      settlement = sell_price + adjustment_total

    ELSE IF platform_fee_rate IS NOT NULL:
      fee = ROUND(sell_price × platform_fee_rate)
      settlement = sell_price - fee + adjustment_total
  ```

### 5-2. sync_sale_adjustment_total (조정금액 합계 동기화)
- **트리거 시점**: sale_adjustments INSERT/UPDATE/DELETE 후 (AFTER)
- **로직**:
  ```
  sale_id = NEW.sale_id 또는 OLD.sale_id
  total = SUM(amount) FROM sale_adjustments WHERE sale_id = ?
  UPDATE sales SET adjustment_total = total WHERE id = sale_id
  → 이 UPDATE가 calculate_sale_settlement 트리거를 다시 발동시켜 settlement_amount도 재계산됨
  ```

### 5-3. calculate_vat_refundable (부가세 환급액 계산)
- **트리거 시점**: purchases INSERT/UPDATE 전 (BEFORE)
- **로직**:
  ```
  items에서 is_personal 조회
  IF is_personal == FALSE AND payment_method == 'CORPORATE_CARD':
    vat_refundable = ROUND(purchase_price / 11.0, 2)
  ELSE:
    vat_refundable = 0
  ```

### 5-4. update_updated_at (items 수정 시간 자동 갱신)
- **트리거 시점**: items UPDATE 전 (BEFORE)
- **로직**: `updated_at = now()`
- **Drift**: `beforeUpdate` 콜백에서 처리

### 5-5. set_inspection_return_seq (검수반려 순번 자동 생성)
- **트리거 시점**: inspection_rejections INSERT 전 (BEFORE)
- **로직**:
  ```
  IF return_seq IS NULL:
    return_seq = MAX(return_seq) + 1 FROM inspection_rejections WHERE item_id = ?
  ```

### 5-6. set_shipment_seq (배송 순번 자동 생성)
- **트리거 시점**: shipments INSERT 전 (BEFORE)
- **로직**:
  ```
  IF seq IS NULL:
    seq = MAX(seq) + 1 FROM shipments WHERE item_id = ?
  ```

### 5-7. update_item_status (RPC 함수 — 상태 변경 + 로그 자동 기록)
- **PostgreSQL RPC 함수** (트리거 아님)
- **로직**:
  ```
  1. old_status = SELECT current_status FROM items WHERE id = ?
  2. UPDATE items SET current_status = new_status, updated_at = now()
  3. INSERT INTO status_logs (item_id, old_status, new_status, note)
  ```
- **Drift**: DAO 메서드로 구현 (transaction 내에서 items UPDATE + status_logs INSERT)

### 5-8. get_fifo_item (RPC 함수 — FIFO 재고 조회)
- **로직**:
  ```
  SELECT i.* FROM items i
  JOIN products p ON i.product_id = p.id
  WHERE p.model_code = ? AND i.current_status = 'OFFICE_STOCK'
    AND i.is_personal = FALSE
    AND (size_kr IS NULL OR i.size_kr = ?)
  ORDER BY i.created_at ASC LIMIT 1
  ```

---

## 6. platform_fee_rules 초기 데이터 (시드)

로컬 DB 생성 시 아래 데이터를 시드해야 한다.

| platform | category | fee_rate | min_fee | max_fee | note |
|---|---|---|---|---|---|
| POIZON | default | 0.1000 | 15000 | 45000 | 신발·의류·기타 |
| POIZON | bag | 0.1400 | 18000 | 45000 | 가방·캐리어 |
| POIZON | bags | 0.1400 | 18000 | 45000 | 가방(복수형) |
| POIZON | carrier | 0.1400 | 18000 | 45000 | 캐리어 |
| POIZON | acc | 0.1400 | 18000 | 45000 | 악세사리(약어) |
| POIZON | accessories | 0.1400 | 18000 | 45000 | 악세사리류 |
| POIZON | accessory | 0.1400 | 18000 | 45000 | 악세사리(단수) |
| POIZON | watch | 0.1400 | 18000 | 45000 | 시계류 |
| POIZON | watches | 0.1400 | 18000 | 45000 | 시계류(복수형) |

---

## 7. 인덱스 (성능 최적화)

Drift에서도 아래 인덱스를 생성해야 한다.

### 필수 인덱스
```sql
-- items
CREATE INDEX idx_items_current_status ON items(current_status);
CREATE INDEX idx_items_product_id ON items(product_id);
CREATE INDEX idx_items_is_personal ON items(is_personal);
CREATE INDEX idx_items_status_personal ON items(current_status, is_personal);
CREATE INDEX idx_items_created_at ON items(created_at);
CREATE INDEX idx_items_poizon_sku_id ON items(poizon_sku_id) WHERE poizon_sku_id IS NOT NULL;

-- purchases
CREATE INDEX idx_purchases_item_id ON purchases(item_id);
CREATE INDEX idx_purchases_purchase_date ON purchases(purchase_date);

-- sales
CREATE INDEX idx_sales_item_id ON sales(item_id);
CREATE INDEX idx_sales_platform ON sales(platform);
CREATE INDEX idx_sales_sale_date ON sales(sale_date);
CREATE INDEX idx_sales_data_source ON sales(data_source);
CREATE INDEX idx_sales_poizon_order_id ON sales(poizon_order_id) WHERE poizon_order_id IS NOT NULL;

-- status_logs
CREATE INDEX idx_status_logs_item_id ON status_logs(item_id);

-- shipments
CREATE INDEX idx_shipments_item_id ON shipments(item_id);
CREATE INDEX idx_shipments_tracking_number ON shipments(tracking_number);

-- inspection_rejections
CREATE INDEX idx_inspection_rejections_item_id ON inspection_rejections(item_id);

-- repairs
CREATE INDEX idx_repairs_item_id ON repairs(item_id);

-- sale_adjustments
CREATE INDEX idx_sale_adjustments_sale_id ON sale_adjustments(sale_id);

-- size_charts
CREATE INDEX idx_size_charts_brand ON size_charts(brand);
CREATE INDEX idx_size_charts_target ON size_charts(target);

-- bot_review_queue
CREATE INDEX idx_bot_review_queue_item_id ON bot_review_queue(item_id);
CREATE INDEX idx_bot_review_queue_status ON bot_review_queue(status);
CREATE INDEX idx_bot_review_queue_created_at ON bot_review_queue(created_at DESC);
```

---

## 8. 뷰 (참고용 — Drift에서 구현 방법 선택)

뷰는 Drift의 `@DriftView` 또는 커스텀 쿼리로 구현 가능. 아래는 참고용 SQL.

### v_inventory_overview (가장 중요한 뷰)
```sql
SELECT
  i.id, p.model_code, p.model_name, p.image_url, p.category,
  b.name AS brand_name, b.code AS brand_code,
  i.size_kr, i.sku, i.current_status, i.is_personal,
  i.location, i.defect_note,
  pu.purchase_price, pu.payment_method, pu.vat_refundable,
  pu.purchase_date, pu.source_id, pu.memo AS purchase_memo,
  so.name AS source_name,
  s.id AS sale_id, s.platform, s.platform_option,
  s.listed_price, s.sell_price, s.platform_fee, s.platform_fee_rate,
  s.adjustment_total, s.outgoing_date, s.sale_date, s.settled_at,
  s.settlement_amount, s.shipment_deadline,
  COALESCE(s.tracking_number, i.tracking_number) AS tracking_number,
  s.memo AS sale_memo,
  (SELECT count(*) FROM inspection_rejections ir WHERE ir.item_id = i.id) AS rejection_count,
  CASE
    WHEN s.settlement_amount IS NOT NULL AND pu.purchase_price IS NOT NULL
    THEN ROUND(s.settlement_amount - pu.purchase_price + COALESCE(pu.vat_refundable, 0))
  END AS profit,
  CASE
    WHEN s.settlement_amount IS NOT NULL AND pu.purchase_price IS NOT NULL AND pu.purchase_price > 0
    THEN ROUND(((s.settlement_amount - pu.purchase_price + COALESCE(pu.vat_refundable, 0)) / pu.purchase_price) * 100, 2)
  END AS margin_rate,
  i.created_at, i.updated_at
FROM items i
JOIN products p ON i.product_id = p.id
LEFT JOIN brands b ON p.brand_id = b.id
LEFT JOIN purchases pu ON pu.item_id = i.id
LEFT JOIN sources so ON so.id = pu.source_id
LEFT JOIN sales s ON s.item_id = i.id
```

### v_dashboard_stats
```sql
SELECT
  count(*) FILTER (WHERE current_status = 'ORDER_PLACED') AS order_placed_count,
  count(*) FILTER (WHERE current_status = 'OFFICE_STOCK') AS office_stock_count,
  count(*) FILTER (WHERE current_status = 'OUTGOING') AS outgoing_count,
  count(*) FILTER (WHERE current_status = 'IN_INSPECTION') AS in_inspection_count,
  count(*) FILTER (WHERE current_status = 'LISTED') AS listed_count,
  count(*) FILTER (WHERE current_status IN ('DEFECT_FOR_SALE','DEFECT_SOLD')) AS defect_count,
  count(*) FILTER (WHERE current_status = 'DEFECT_HELD') AS defect_held_count,
  count(*) FILTER (WHERE current_status = 'RETURNING') AS returning_count,
  count(*) FILTER (WHERE current_status = 'REPAIRING') AS repairing_count,
  count(*) FILTER (WHERE current_status IN (
    'ORDER_PLACED','OFFICE_STOCK','OUTGOING','IN_INSPECTION','LISTED',
    'DEFECT_FOR_SALE','DEFECT_HELD','RETURNING','REPAIRING'
  )) AS total_active_stock
FROM items
```

> **주의**: `FILTER (WHERE ...)` 구문은 SQLite에서 지원하지 않음.
> SQLite에서는 `SUM(CASE WHEN current_status = 'X' THEN 1 ELSE 0 END)` 형태로 변환 필요.

---

## 9. 백업 데이터 가져오기 (초기 마이그레이션)

### 백업 JSON 파일 위치
```
d:\dev\2026\my_project\merchant_manage\backups\2026-03-15_12-26-16\
├── brands.json          (198건)
├── sources.json         (39건)
├── products.json        (371건 → 최신 DB는 371건)
├── size_charts.json     (372건)
├── items.json           (1,161건 → 최신 DB는 1,197건)
├── purchases.json       (1,161건 → 최신 DB는 1,196건)
├── sales.json           (1,159건 → 최신 DB는 1,195건)
├── sale_adjustments.json (1건)
├── status_logs.json     (795건 → 최신 DB는 993건)
└── _meta.json
```

> ⚠️ 백업은 2026-03-15 기준이므로 최신 데이터와 차이가 있음.
> 최신 데이터가 필요하면 `node --env-file=.env.local scripts/backup-db.mjs` 재실행 후 사용.

### JSON 데이터 구조 예시

**brands.json**
```json
{
  "id": "044afd0e-1ef4-4779-a9b0-98145b40bf29",
  "name": "SALOMON",
  "code": null,
  "created_at": "2026-03-04T08:13:12.839552+00:00"
}
```

**items.json**
```json
{
  "id": "006bfbbd-9c2b-44f3-8816-ab8835e562b9",
  "product_id": "1d489d6e-c16c-49ab-85a1-0649d56a96f3",
  "sku": "ID6600-245-001",
  "size_kr": "245",
  "size_eu": null,
  "size_us": null,
  "size_etc": null,
  "barcode": null,
  "tracking_number": null,
  "is_personal": false,
  "current_status": "SETTLED",
  "location": null,
  "defect_note": null,
  "note": null,
  "created_at": "2026-03-04T12:07:42.772421+00:00",
  "updated_at": "2026-03-04T12:07:42.772421+00:00"
}
```

**sales.json**
```json
{
  "id": "014b27e3-f2d2-4f08-930a-481b1680752e",
  "item_id": "0dd70937-4eca-4c36-882f-c0cc1fd4a778",
  "sale_date": "2026-02-04",
  "platform": "POIZON",
  "platform_option": "KR 그린 화이트 레드 KR 255",
  "listed_price": null,
  "sell_price": 79000,
  "platform_fee_rate": 0.1899,
  "platform_fee": 15000,
  "settlement_amount": 64000,
  "adjustment_total": 0,
  "outgoing_date": "2026-02-05",
  "shipment_deadline": null,
  "tracking_number": "696182523071",
  "settled_at": "2026-02-04",
  "memo": "POIZON_ORDER:21313130390453299",
  "created_at": "2026-03-04T12:07:43.295591+00:00"
}
```

### 가져오기 순서 (FK 의존성 준수)
1. brands
2. sources
3. products
4. size_charts
5. platform_fee_rules (시드 데이터)
6. items
7. purchases
8. sales
9. sale_adjustments
10. status_logs
11. inspection_rejections
12. repairs
13. shipments
14. supplier_returns
15. order_cancellations
16. sample_usages

### 주의사항
- `poizon_sku_id` 컬럼은 items.json 백업에 포함되지 않을 수 있음 (나중에 추가된 컬럼)
- `poizon_order_id`, `data_source` 컬럼도 sales.json에 없을 수 있음
- 없는 필드는 NULL로 처리
- `is_personal` 은 JSON에서 `true/false` → SQLite에서 `1/0`으로 변환

---

## 10. CRDT 확장 고려사항

dev-setup-guide.md의 CRDT 전략에 따라, 각 테이블에 아래 컬럼 추가를 고려:

```
hlc       TEXT    -- Hybrid Logical Clock 타임스탬프
is_deleted INTEGER DEFAULT 0  -- soft delete
```

단, 초기 마이그레이션(Supabase 데이터 가져오기) 시에는 CRDT 없이 단순 INSERT하고,
이후 로컬에서 데이터 수정이 발생할 때부터 HLC를 기록하면 된다.

---

*추출일: 2026-03-22 | 소스: Supabase 운영 DB (rjaoaewdmehbehgniqyi)*
