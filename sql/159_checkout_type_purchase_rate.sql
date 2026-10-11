-- 목적: "상품0개 결제시작만 있던 유저"와 "상품 있는 결제시작 유저"의 구매율을,
-- 담기기록 유무로 나눠서 기간별로 비교 - 0개 결제시작이 진짜/가짜인지 판단.

WITH first_checkout_event AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    PARSE_DATE('%Y%m%d', event_date) AS first_checkout_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'begin_checkout'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp ASC) = 1
),
all_checkouts AS (
  SELECT
    user_pseudo_id,
    ARRAY_LENGTH(items) AS item_count
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'begin_checkout'
),
user_checkout_type AS (
  SELECT
    user_pseudo_id,
    MAX(CASE WHEN item_count > 0 THEN 1 ELSE 0 END) AS has_items_checkout
  FROM all_checkouts
  GROUP BY user_pseudo_id
),
any_cart AS (
  SELECT DISTINCT user_pseudo_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
),
any_purchase AS (
  SELECT
    user_pseudo_id,
    MIN(PARSE_DATE('%Y%m%d', event_date)) AS first_purchase_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
  GROUP BY user_pseudo_id
),
labeled AS (
  SELECT
    fc.user_pseudo_id,
    CASE
      WHEN fc.first_checkout_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간'
      WHEN fc.first_checkout_date BETWEEN '2020-11-23' AND '2020-11-30' THEN '블프구간'
      WHEN fc.first_checkout_date < '2020-12-14' THEN '평상시'
      ELSE '사후구간'
    END AS period,
    CASE WHEN uct.has_items_checkout = 1 THEN '상품있는결제시작' ELSE '상품0개결제시작만' END AS checkout_type,
    CASE WHEN ac.user_pseudo_id IS NOT NULL THEN '담기기록있음' ELSE '담기기록없음' END AS cart_log_status,
    CASE WHEN ap.first_purchase_date IS NOT NULL THEN 1 ELSE 0 END AS did_purchase
  FROM first_checkout_event fc
  JOIN user_checkout_type uct ON uct.user_pseudo_id = fc.user_pseudo_id
  LEFT JOIN any_cart ac ON ac.user_pseudo_id = fc.user_pseudo_id
  LEFT JOIN any_purchase ap ON ap.user_pseudo_id = fc.user_pseudo_id
)
SELECT
  period,
  checkout_type,
  cart_log_status,
  COUNT(*) AS users,
  SUM(did_purchase) AS purchased,
  ROUND(SAFE_DIVIDE(SUM(did_purchase), COUNT(*)) * 100, 2) AS purchase_rate
FROM labeled
GROUP BY period, checkout_type, cart_log_status
ORDER BY period, checkout_type, cart_log_status
