-- 목적: Revenue 단계(구매 퍼널) 진단. 문제구간(2020-12-28~2021-01-04)과 평상시를 디바이스별로 나눠
-- view_item -> add_to_cart -> begin_checkout -> purchase 단계별 전환율을 비교해 병목을 찾는다.
-- 세션 단위 집계 (01_health_check_weekly.sql과 동일한 방식으로 일관성 유지)

WITH session_funnel AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    device.category AS device_category,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    MAX(CASE WHEN event_name = 'view_item' THEN 1 ELSE 0 END) AS has_view_item,
    MAX(CASE WHEN event_name = 'add_to_cart' THEN 1 ELSE 0 END) AS has_add_to_cart,
    MAX(CASE WHEN event_name = 'begin_checkout' THEN 1 ELSE 0 END) AS has_begin_checkout,
    MAX(CASE WHEN event_name = 'purchase' THEN 1 ELSE 0 END) AS has_purchase
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  GROUP BY user_pseudo_id, session_id, device_category, event_date
),
labeled AS (
  SELECT
    *,
    CASE
      WHEN event_date BETWEEN '2020-12-28' AND '2021-01-04' THEN '문제구간'
      ELSE '평상시'
    END AS period
  FROM session_funnel
  WHERE session_id IS NOT NULL
)
SELECT
  period,
  device_category,
  COUNT(*) AS sessions,
  SUM(has_view_item) AS view_item_sessions,
  SUM(has_add_to_cart) AS add_to_cart_sessions,
  SUM(has_begin_checkout) AS begin_checkout_sessions,
  SUM(has_purchase) AS purchase_sessions,
  ROUND(SAFE_DIVIDE(SUM(has_add_to_cart), SUM(has_view_item)) * 100, 2) AS view_to_cart_cr,
  ROUND(SAFE_DIVIDE(SUM(has_begin_checkout), SUM(has_add_to_cart)) * 100, 2) AS cart_to_checkout_cr,
  ROUND(SAFE_DIVIDE(SUM(has_purchase), SUM(has_begin_checkout)) * 100, 2) AS checkout_to_purchase_cr
FROM labeled
GROUP BY period, device_category
ORDER BY period, device_category
