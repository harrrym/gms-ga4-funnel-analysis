-- [transaction_id 통합 키] transaction_id는 2020-11-01~11-12 구간에서는 int_value 칸에, 이후에는 string_value 칸에 저장돼 있다.
-- string_value만 읽으면 int_value 칸의 456행을 "번호 없음"으로 잘못 처리하므로 두 칸을 COALESCE로 합쳐 하나의 키로 쓴다 (docs/05 참고).
-- 목적: 34번 google/cpc 신규유저 LTR의 정제본 (같은 transaction_id는 1건만 남김).
-- 34번과 동일하되 매출 합산에서 중복 purchase를 제거했다.

WITH session_events AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
    traffic_source.source AS source,
    traffic_source.medium AS medium
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
cpc_new_users AS (
  SELECT DISTINCT user_pseudo_id
  FROM session_events
  WHERE session_number = 1 AND session_id IS NOT NULL
    AND source = 'google' AND medium = 'cpc'
),
purchases_raw AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    COALESCE(
      (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'transaction_id'),
      CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS STRING)
    ) AS transaction_id,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),
purchases AS (
  SELECT *
  FROM purchases_raw
  WHERE TRUE
  QUALIFY transaction_id IS NULL
       OR ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY event_timestamp) = 1
),
user_revenue AS (
  SELECT
    c.user_pseudo_id,
    COALESCE(SUM(p.revenue), 0) AS ltr
  FROM cpc_new_users c
  LEFT JOIN purchases p USING (user_pseudo_id)
  GROUP BY c.user_pseudo_id
)
SELECT
  COUNT(*) AS cpc_new_users,
  COUNTIF(ltr > 0) AS cpc_converters,
  ROUND(SUM(ltr), 2) AS total_ltr,
  ROUND(AVG(ltr), 3) AS avg_ltr_per_new_user,
  ROUND(SAFE_DIVIDE(SUM(ltr), COUNTIF(ltr > 0)), 2) AS avg_ltr_per_converter
FROM user_revenue
