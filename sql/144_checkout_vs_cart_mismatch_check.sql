-- 목적: 결제시작 이벤트 수가 담기 이벤트 수보다 많은 카테고리(예: 하락구간 Stationery/Writing)의 원인 확인.
-- 가설: (1) begin_checkout이 세션/유저당 중복 기록, (2) 담기 없이 바로 결제, (3) 이전 기간에 담은 상품이 이번 기간 결제에 포함(카트 이연).

WITH begin_checkout_events AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    event_timestamp,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'begin_checkout'
),
decline_checkouts AS (
  SELECT * FROM begin_checkout_events
  WHERE event_date BETWEEN '2020-12-14' AND '2021-01-11'
),
-- (1) 유저당, 세션당 begin_checkout 중복 횟수
per_user AS (
  SELECT user_pseudo_id, COUNT(*) AS checkout_event_count
  FROM decline_checkouts
  GROUP BY user_pseudo_id
),
per_session AS (
  SELECT user_pseudo_id, session_id, COUNT(*) AS checkout_event_count
  FROM decline_checkouts
  GROUP BY user_pseudo_id, session_id
),
-- (2)/(3) 각 유저의 "첫 add_to_cart 날짜"와 이번 begin_checkout 날짜 비교
first_cart AS (
  SELECT
    user_pseudo_id,
    MIN(PARSE_DATE('%Y%m%d', event_date)) AS first_cart_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
  GROUP BY user_pseudo_id
),
checkout_users_distinct AS (
  SELECT DISTINCT user_pseudo_id, event_date AS checkout_date
  FROM decline_checkouts
)
SELECT
  (SELECT COUNT(*) FROM decline_checkouts) AS total_checkout_events,
  (SELECT COUNT(DISTINCT user_pseudo_id) FROM decline_checkouts) AS distinct_checkout_users,
  (SELECT ROUND(AVG(checkout_event_count), 2) FROM per_user) AS avg_checkout_events_per_user,
  (SELECT MAX(checkout_event_count) FROM per_user) AS max_checkout_events_per_user,
  (SELECT ROUND(AVG(checkout_event_count), 2) FROM per_session) AS avg_checkout_events_per_session,
  (SELECT COUNT(*) FROM checkout_users_distinct cu
     LEFT JOIN first_cart fc ON fc.user_pseudo_id = cu.user_pseudo_id
     WHERE fc.first_cart_date IS NULL) AS checkout_without_any_cart_event,
  (SELECT COUNT(*) FROM checkout_users_distinct cu
     JOIN first_cart fc ON fc.user_pseudo_id = cu.user_pseudo_id
     WHERE fc.first_cart_date < cu.checkout_date) AS checkout_with_earlier_cart_date,
  (SELECT COUNT(*) FROM checkout_users_distinct cu
     JOIN first_cart fc ON fc.user_pseudo_id = cu.user_pseudo_id
     WHERE fc.first_cart_date < '2020-12-14') AS checkout_users_first_cart_before_decline
