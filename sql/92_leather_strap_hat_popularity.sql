-- 목적: "Google Leather Strap Hat Black/Blue"가 실제로 잘 팔리던(인기 있던) 상품이었는지 확인.
-- 평상시(하락구간 이전) 기준으로 Hats 카테고리 내 상품별 담기/구매 횟수를 비교.

WITH hats_add_to_cart AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    item.item_name AS item_name,
    item.item_category AS category
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
    AND item.item_category LIKE '%Hat%'
),
hats_purchase AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    item.item_name AS item_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND item.item_name IN (
      SELECT DISTINCT item_name FROM hats_add_to_cart
    )
)
SELECT
  a.item_name,
  COUNTIF(a.event_date < '2020-12-14') AS add_to_cart_baseline,
  COUNTIF(a.event_date BETWEEN '2020-12-14' AND '2021-01-11') AS add_to_cart_decline,
  (SELECT COUNT(*) FROM hats_purchase p WHERE p.item_name = a.item_name AND p.event_date < '2020-12-14') AS purchase_baseline,
  (SELECT COUNT(*) FROM hats_purchase p WHERE p.item_name = a.item_name AND p.event_date BETWEEN '2020-12-14' AND '2021-01-11') AS purchase_decline
FROM hats_add_to_cart a
GROUP BY a.item_name
ORDER BY add_to_cart_baseline DESC
