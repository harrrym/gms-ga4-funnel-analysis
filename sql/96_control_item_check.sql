-- 목적: "품절이면 담기도 막힌다"는 전제, 그리고 "이 14개가 특별히 이상하다"는 비교 기준을 세우기 위해
-- 베스트셀러가 아니면서 하락구간에도 구매가 정상적으로(0이 아니게) 잡히는 평범한 상품을 찾아 대조군으로 확인.
-- 평상시 구매 20~80건(의심 상품들과 비슷한 볼륨) 사이이면서 하락구간 구매가 0이 아닌 상품을 뽑는다.

WITH purchase_items AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    item.item_name AS item_name,
    item.item_category AS category
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
    ANY_VALUE(category) AS category,
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
)
SELECT
  p.item_name,
  p.category,
  c.cart_baseline,
  c.cart_decline,
  p.purchase_baseline,
  p.purchase_decline
FROM purchase_agg p
JOIN cart_agg c ON c.item_name = p.item_name
WHERE p.purchase_baseline BETWEEN 20 AND 80
  AND p.purchase_decline > 0
ORDER BY p.purchase_baseline DESC
LIMIT 15
