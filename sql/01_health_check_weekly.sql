-- 목적: OMTM 설정 근거 마련 (그로스해킹 Q2 서비스 라이프사이클 단계 판단 / Q3 가장 신경쓰이는 문제 발견)
-- 주간 단위로 세션 수, 사용자 수, 구매 세션 수, 구매전환율 추세를 확인한다.

WITH session_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
sessions AS (
  SELECT
    DATE_TRUNC(event_date, WEEK(MONDAY)) AS week_start,
    user_pseudo_id,
    CONCAT(user_pseudo_id, '-', CAST(session_id AS STRING)) AS session_key,
    LOGICAL_OR(event_name = 'purchase') AS has_purchased
  FROM session_events
  WHERE session_id IS NOT NULL
  GROUP BY week_start, user_pseudo_id, session_key
)
SELECT
  week_start,
  COUNT(DISTINCT user_pseudo_id) AS user_count,
  COUNT(DISTINCT session_key) AS session_count,
  COUNTIF(has_purchased) AS purchase_session_count,
  ROUND(SAFE_DIVIDE(COUNTIF(has_purchased), COUNT(DISTINCT session_key)) * 100, 2) AS conversion_rate_pct
FROM sessions
GROUP BY week_start
ORDER BY week_start
