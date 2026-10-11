-- 목적: AARRR의 Activation 단계 진단.
-- Activation 정의: 첫 방문(생애 첫 세션, ga_session_number=1)에서 상품 상세조회(view_item)까지
-- 도달했는가 -- "핵심 가치(실제 상품을 구경하는 경험)를 처음 방문에서 느꼈는가"의 근사 지표.
-- 주의: ga_session_number=1은 "진짜 생애 첫 방문"이 아니라 "이 추적 식별자(쿠키) 기준 첫 세션"이다.
-- 쿠키 리셋 등으로 실제 재방문자가 섞여있을 수 있다 (docs/03_aarrr_diagnosis.md 참고).

WITH first_session_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
first_sessions AS (
  SELECT
    DATE_TRUNC(event_date, WEEK(MONDAY)) AS week_start,
    user_pseudo_id,
    session_id,
    MAX(CASE WHEN event_name = 'view_item' THEN 1 ELSE 0 END) AS reached_view_item
  FROM first_session_events
  WHERE session_id IS NOT NULL AND session_number = 1
  GROUP BY week_start, user_pseudo_id, session_id
)
SELECT
  week_start,
  COUNT(*) AS first_time_sessions,
  SUM(reached_view_item) AS activated_sessions,
  ROUND(SAFE_DIVIDE(SUM(reached_view_item), COUNT(*)) * 100, 2) AS activation_rate_pct
FROM first_sessions
GROUP BY week_start
ORDER BY week_start
