-- 목적: 데이터 전체 3개월 안에서 session_number=1이 한 번도 관측되지 않은(2 이상부터 등장하는) 유저 규모를 확인한다.
-- 이게 "이전부터 방문해온 기존고객이 카운터를 이어받아 등장한다"는 가설의 직접적인 검증이다.

WITH session_events AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
user_min_session AS (
  SELECT
    user_pseudo_id,
    MIN(session_number) AS min_session_number
  FROM session_events
  WHERE session_id IS NOT NULL AND session_number IS NOT NULL
  GROUP BY user_pseudo_id
)
SELECT
  CASE WHEN min_session_number = 1 THEN '1이 관측됨(신규유저로 확인 가능)' ELSE '1이 관측 안 됨(기존고객 추정)' END AS category,
  COUNT(*) AS user_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM user_min_session
GROUP BY category
