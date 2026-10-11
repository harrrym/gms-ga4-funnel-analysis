-- 목적: 04번 쿼리는 문제구간(2주) vs 평상시(11주 평균)로 이분해서 비교했는데,
-- 평상시를 11주 평균으로 뭉개면 "평상시 74~76%"가 실제로 안정적인 수준인지,
-- 아니면 특정 몇 주가 그 평균을 끌어올린 이상치인지 알 수 없다.
-- 주 단위로 쪼개서 cart_to_checkout_cr이 어떻게 움직였는지 실제 흐름을 확인한다.

WITH session_funnel AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    MAX(CASE WHEN event_name = 'add_to_cart' THEN 1 ELSE 0 END) AS has_add_to_cart,
    MAX(CASE WHEN event_name = 'begin_checkout' THEN 1 ELSE 0 END) AS has_begin_checkout
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  GROUP BY user_pseudo_id, session_id, event_date
),
weekly AS (
  SELECT
    DATE_TRUNC(event_date, WEEK(MONDAY)) AS week_start,
    SUM(has_add_to_cart) AS add_to_cart_sessions,
    SUM(has_begin_checkout) AS begin_checkout_sessions
  FROM session_funnel
  WHERE session_id IS NOT NULL
  GROUP BY week_start
)
SELECT
  week_start,
  add_to_cart_sessions,
  begin_checkout_sessions,
  ROUND(SAFE_DIVIDE(begin_checkout_sessions, add_to_cart_sessions) * 100, 2) AS cart_to_checkout_cr
FROM weekly
ORDER BY week_start
