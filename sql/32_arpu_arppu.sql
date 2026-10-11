-- 목적: Revenue 단계 - ARPU(전체 유저 기준 평균매출), ARPPU(구매자 기준 평균매출)을 계산한다.
-- 3개월 전체 합산 값과 주간 추이를 함께 낸다(OMTM 문제구간 12/28~1/4과 겹쳐보기 위함).
-- 기준: 유저 = 그 주(또는 3개월 전체)에 어떤 이벤트든 발생시킨 user_pseudo_id.
-- 구매자 = 그 주(또는 3개월 전체)에 purchase 이벤트가 있었던 user_pseudo_id.

WITH events AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week_start,
    user_pseudo_id,
    event_name,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS transaction_id,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
weekly AS (
  SELECT
    week_start,
    COUNT(DISTINCT user_pseudo_id) AS total_users,
    COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL)) AS paying_users,
    SUM(IF(event_name = 'purchase', revenue, 0)) AS total_revenue
  FROM events
  GROUP BY week_start
),
overall AS (
  SELECT
    CAST(NULL AS DATE) AS week_start,
    COUNT(DISTINCT user_pseudo_id) AS total_users,
    COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL)) AS paying_users,
    SUM(IF(event_name = 'purchase', revenue, 0)) AS total_revenue
  FROM events
)
SELECT
  week_start,
  total_users,
  paying_users,
  ROUND(total_revenue, 2) AS total_revenue,
  ROUND(SAFE_DIVIDE(total_revenue, total_users), 3) AS arpu,
  ROUND(SAFE_DIVIDE(total_revenue, paying_users), 3) AS arppu
FROM (SELECT * FROM overall UNION ALL SELECT * FROM weekly)
ORDER BY week_start IS NULL DESC, week_start
