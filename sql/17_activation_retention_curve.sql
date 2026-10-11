-- 목적: Activation 아하모먼트 후보(view_search_results, 첫 세션에서 사이트 내 검색 사용)가
-- 실제로 이후 리텐션(재방문)과 관련 있는지, 체크포인트별(1/3/7/14/30일) 재방문 여부로 확인한다.
-- 유저 단위 결과를 그대로 내보내고, 코호트 절단(censoring) 처리는 Python에서 진행한다.

WITH session_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
first_session_behavior AS (
  SELECT
    user_pseudo_id,
    MIN(event_date) AS first_date,
    MAX(CASE WHEN event_name = 'view_search_results' THEN 1 ELSE 0 END) AS did_search
  FROM session_events
  WHERE session_number = 1 AND session_id IS NOT NULL
  GROUP BY user_pseudo_id
),
later_activity AS (
  SELECT DISTINCT user_pseudo_id, event_date
  FROM session_events
  WHERE session_id IS NOT NULL
)
SELECT
  fsb.user_pseudo_id,
  fsb.first_date,
  fsb.did_search,
  MAX(CASE WHEN DATE_DIFF(la.event_date, fsb.first_date, DAY) BETWEEN 1 AND 1 THEN 1 ELSE 0 END) AS returned_1d,
  MAX(CASE WHEN DATE_DIFF(la.event_date, fsb.first_date, DAY) BETWEEN 1 AND 3 THEN 1 ELSE 0 END) AS returned_3d,
  MAX(CASE WHEN DATE_DIFF(la.event_date, fsb.first_date, DAY) BETWEEN 1 AND 7 THEN 1 ELSE 0 END) AS returned_7d,
  MAX(CASE WHEN DATE_DIFF(la.event_date, fsb.first_date, DAY) BETWEEN 1 AND 14 THEN 1 ELSE 0 END) AS returned_14d,
  MAX(CASE WHEN DATE_DIFF(la.event_date, fsb.first_date, DAY) BETWEEN 1 AND 30 THEN 1 ELSE 0 END) AS returned_30d
FROM first_session_behavior fsb
LEFT JOIN later_activity la ON fsb.user_pseudo_id = la.user_pseudo_id
GROUP BY fsb.user_pseudo_id, fsb.first_date, fsb.did_search
