-- 목적: 12/10~12/25 일별 cart->checkout 전환율(일별 코호트)과 구매 건수를 같이 본다.
-- 12/18(빠른 배송 마감 안내) 전후로 꺾이는지 확인.

WITH first_cart_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_cart_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp ASC) = 1
),
events AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
user_outcome AS (
  SELECT
    fc.user_pseudo_id,
    fc.first_cart_date,
    MAX(CASE WHEN e.event_name = 'begin_checkout' AND e.event_date >= fc.first_cart_date THEN 1 ELSE 0 END) AS did_checkout
  FROM first_cart_event fc
  LEFT JOIN events e ON e.user_pseudo_id = fc.user_pseudo_id
  WHERE fc.first_cart_date BETWEEN '2020-12-10' AND '2020-12-25'
  GROUP BY fc.user_pseudo_id, fc.first_cart_date
),
daily_cart AS (
  SELECT
    first_cart_date AS day,
    COUNT(*) AS cart_users,
    SUM(did_checkout) AS checkout_users,
    ROUND(SAFE_DIVIDE(SUM(did_checkout), COUNT(*)) * 100, 2) AS cart_to_checkout_rate
  FROM user_outcome
  GROUP BY day
),
daily_purchase AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS day,
    COUNT(*) AS purchase_events
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201210' AND '20201225'
    AND event_name = 'purchase'
  GROUP BY day
)
SELECT
  dc.day,
  dc.cart_users,
  dc.checkout_users,
  dc.cart_to_checkout_rate,
  dp.purchase_events
FROM daily_cart dc
LEFT JOIN daily_purchase dp ON dp.day = dc.day
ORDER BY dc.day
