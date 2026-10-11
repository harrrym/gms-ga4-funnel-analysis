-- 목적: Acquisition 단계 진단. 식별 가능한 채널별 신규유저 유입 규모를 주간 추이로 확인한다.
-- 특정 구간을 미리 전제하지 않고 전체 기간을 있는 그대로 본다.
-- 주의: "신규유저"(ga_session_number=1)는 쿠키 기반 식별자의 첫 세션이지 진짜 생애 첫 방문 보장이 아니다.
-- 쿠키 리셋된 재방문자가 일부 섞여있을 수 있다 (docs/03_aarrr_diagnosis.md 참고).

WITH first_sessions AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
    traffic_source.source AS source,
    traffic_source.medium AS medium
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
new_users AS (
  SELECT
    DATE_TRUNC(event_date, WEEK(MONDAY)) AS week_start,
    user_pseudo_id,
    session_id,
    ANY_VALUE(source) AS source,
    ANY_VALUE(medium) AS medium
  FROM first_sessions
  WHERE session_id IS NOT NULL AND session_number = 1
  GROUP BY week_start, user_pseudo_id, session_id
),
channeled AS (
  SELECT
    week_start,
    CASE
      WHEN source = 'google' AND medium = 'organic' THEN 'google/organic'
      WHEN source = '(direct)' AND medium = '(none)' THEN 'direct'
      WHEN source = 'google' AND medium = 'cpc' THEN 'google/cpc'
      WHEN source = 'shop.googlemerchandisestore.com' AND medium = 'referral' THEN 'self-referral'
      WHEN source = '<Other>' OR medium = '<Other>' OR source = '(data deleted)' OR medium = '(data deleted)' THEN '식별불가/기타'
      ELSE '식별불가/기타'
    END AS channel
  FROM new_users
)
SELECT
  week_start,
  channel,
  COUNT(*) AS new_users
FROM channeled
GROUP BY week_start, channel
ORDER BY week_start, new_users DESC
