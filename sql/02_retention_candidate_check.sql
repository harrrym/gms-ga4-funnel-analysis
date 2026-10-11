-- 목적: OMTM 후보 비교를 공정하게 하기 위해 리텐션(재방문 유저 비율)도 같은 방식으로 확인한다.
-- ga_session_number: GA4가 유저별로 매기는 세션 순번(1=첫 세션, 2 이상=재방문 세션)

WITH session_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
user_week AS (
  SELECT
    DATE_TRUNC(event_date, WEEK(MONDAY)) AS week_start,
    user_pseudo_id,
    MAX(session_number) AS max_session_number
  FROM session_events
  WHERE session_id IS NOT NULL
  GROUP BY week_start, user_pseudo_id
)
SELECT
  week_start,
  COUNT(DISTINCT user_pseudo_id) AS user_count,
  COUNTIF(max_session_number > 1) AS returning_user_count,
  ROUND(SAFE_DIVIDE(COUNTIF(max_session_number > 1), COUNT(DISTINCT user_pseudo_id)) * 100, 2) AS returning_user_rate_pct
FROM user_week
GROUP BY week_start
ORDER BY week_start
