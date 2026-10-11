-- 목적: Acquisition 단계 진단. 신규 유저(생애 첫 세션) 기준으로 유입 채널(source/medium) 분포를 확인한다.
-- 세션이 아닌 신규유저 기준으로 잡은 이유: Acquisition은 "누가 어디서 처음 유입됐는가"를 보는 것이므로
-- 재방문 세션까지 섞으면 채널 성과가 왜곡될 수 있음 (사용자와 합의한 기준)
-- 주의: "신규유저"(ga_session_number=1)는 쿠키 기반 식별자의 첫 세션이지 진짜 생애 첫 방문 보장이 아니다.
-- 쿠키 리셋된 재방문자가 일부 섞여있을 수 있다 (docs/03_aarrr_diagnosis.md 참고).

WITH first_sessions AS (
  SELECT
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
    user_pseudo_id,
    session_id,
    ANY_VALUE(source) AS source,
    ANY_VALUE(medium) AS medium
  FROM first_sessions
  WHERE session_id IS NOT NULL AND session_number = 1
  GROUP BY user_pseudo_id, session_id
)
SELECT
  source,
  medium,
  COUNT(*) AS new_users,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM new_users
GROUP BY source, medium
ORDER BY new_users DESC
