-- 목적: CAC 추정을 위한 재료. google/cpc 전체 세션수(신규+재방문)를 주간으로 집계.
-- 광고는 재방문자도 클릭하므로, 비용 추정엔 신규유저만이 아니라 전체 세션수가 필요하다.

WITH session_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    traffic_source.source AS source,
    traffic_source.medium AS medium
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
cpc_sessions AS (
  SELECT
    DATE_TRUNC(event_date, WEEK(MONDAY)) AS week_start,
    user_pseudo_id,
    session_id
  FROM session_events
  WHERE source = 'google' AND medium = 'cpc' AND session_id IS NOT NULL
  GROUP BY week_start, user_pseudo_id, session_id
)
SELECT
  week_start,
  COUNT(*) AS cpc_sessions
FROM cpc_sessions
GROUP BY week_start
ORDER BY week_start
