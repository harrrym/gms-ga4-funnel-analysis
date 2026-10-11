-- 목적: 같은 3개월 데이터에서 세션 기준 전환율과 유저 기준 전환율이 실제로 얼마나 다른지 비교한다.

WITH session_events AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
sessions AS (
  SELECT
    user_pseudo_id,
    session_id,
    LOGICAL_OR(event_name = 'purchase') AS has_purchase
  FROM session_events
  WHERE session_id IS NOT NULL
  GROUP BY user_pseudo_id, session_id
)
SELECT
  -- 세션 기준
  COUNT(*) AS total_sessions,
  COUNTIF(has_purchase) AS purchase_sessions,
  ROUND(SAFE_DIVIDE(COUNTIF(has_purchase), COUNT(*)) * 100, 3) AS session_conversion_rate_pct,
  -- 유저 기준
  COUNT(DISTINCT user_pseudo_id) AS total_users,
  COUNT(DISTINCT CASE WHEN has_purchase THEN user_pseudo_id END) AS purchase_users,
  ROUND(SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN has_purchase THEN user_pseudo_id END),
    COUNT(DISTINCT user_pseudo_id)
  ) * 100, 3) AS user_conversion_rate_pct
FROM sessions
