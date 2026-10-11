-- 목적: CAC 주간 추이 계산을 위해, google/cpc로 처음 유입되어(First-touch) 7일 이내 구매한
-- 신규고객 수를 "유입 주" 기준으로 집계한다.

WITH session_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
    event_name,
    traffic_source.source AS source,
    traffic_source.medium AS medium
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
first_touch AS (
  SELECT
    user_pseudo_id,
    MIN(event_date) AS first_date,
    ANY_VALUE(source) AS source,
    ANY_VALUE(medium) AS medium
  FROM session_events
  WHERE session_number = 1 AND session_id IS NOT NULL
  GROUP BY user_pseudo_id
),
first_purchase AS (
  SELECT
    user_pseudo_id,
    MIN(event_date) AS purchase_date
  FROM session_events
  WHERE event_name = 'purchase'
  GROUP BY user_pseudo_id
)
SELECT
  DATE_TRUNC(ft.first_date, WEEK(MONDAY)) AS week_start,
  COUNT(*) AS cpc_new_conversions
FROM first_touch ft
JOIN first_purchase fp USING (user_pseudo_id)
WHERE ft.source = 'google' AND ft.medium = 'cpc'
  AND DATE_DIFF(fp.purchase_date, ft.first_date, DAY) BETWEEN 0 AND 7
GROUP BY week_start
ORDER BY week_start
