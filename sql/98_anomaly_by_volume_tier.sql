-- 목적: "담기 유지/증가 + 구매=0" 이상 패턴이 베스트셀러에만 몰려있는지, 전체 카탈로그에 고르게
-- 퍼져있는지 확인. 구매량(베스트셀러 정도)으로 상품을 나눠서, 각 구간에서 이 패턴 비율을 비교.

WITH purchase_items AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    item.item_name AS item_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND item.item_name IS NOT NULL
),
cart_items AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    item.item_name AS item_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
    AND item.item_name IS NOT NULL
),
purchase_agg AS (
  SELECT
    item_name,
    COUNTIF(event_date < '2020-12-14') AS purchase_baseline,
    COUNTIF(event_date BETWEEN '2020-12-14' AND '2021-01-11') AS purchase_decline
  FROM purchase_items
  GROUP BY item_name
),
cart_agg AS (
  SELECT
    item_name,
    COUNTIF(event_date < '2020-12-14') AS cart_baseline,
    COUNTIF(event_date BETWEEN '2020-12-14' AND '2021-01-11') AS cart_decline
  FROM cart_items
  GROUP BY item_name
),
joined AS (
  SELECT
    p.item_name,
    p.purchase_baseline,
    p.purchase_decline,
    IFNULL(c.cart_decline, 0) AS cart_decline
  FROM purchase_agg p
  LEFT JOIN cart_agg c ON c.item_name = p.item_name
  WHERE p.purchase_baseline > 0
),
tiered AS (
  SELECT
    *,
    CASE
      WHEN purchase_baseline >= 50 THEN '1. 50건 이상(톱 베스트셀러)'
      WHEN purchase_baseline >= 20 THEN '2. 20~49건(베스트셀러)'
      WHEN purchase_baseline >= 10 THEN '3. 10~19건(중간)'
      WHEN purchase_baseline >= 5 THEN '4. 5~9건(낮음)'
      ELSE '5. 1~4건(매우 낮음)'
    END AS volume_tier,
    CASE WHEN purchase_decline = 0 AND cart_decline > 0 THEN 1 ELSE 0 END AS is_anomaly
  FROM joined
)
SELECT
  volume_tier,
  COUNT(*) AS total_items,
  SUM(CASE WHEN purchase_decline = 0 THEN 1 ELSE 0 END) AS zero_purchase_items,
  SUM(is_anomaly) AS anomaly_items_cart_continues,
  ROUND(SAFE_DIVIDE(SUM(is_anomaly), COUNT(*)) * 100, 2) AS anomaly_pct
FROM tiered
GROUP BY volume_tier
ORDER BY volume_tier
