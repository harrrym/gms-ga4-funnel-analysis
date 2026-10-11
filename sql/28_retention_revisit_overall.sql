-- 목적: Retention 단계 - 코호트로 쪼개지 않고 전체 유저 기준으로 재방문 롤링 리텐션 곡선(Day 1~60)을 그린다.
-- 26번 쿼리와 같은 censoring 처리(각 day_n마다 관찰기간이 부족한 유저는 분모 제외)를 쓰되,
-- 주간 코호트로 쪼개지 않고 전체를 하나로 합쳐서 더 촘촘한 일별 곡선을 얻는다.

WITH events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
first_touch AS (
  SELECT user_pseudo_id, MIN(event_date) AS first_date
  FROM events
  WHERE session_number = 1 AND session_id IS NOT NULL
  GROUP BY user_pseudo_id
),
last_activity AS (
  SELECT user_pseudo_id, MAX(event_date) AS last_date
  FROM events
  GROUP BY user_pseudo_id
),
cohort AS (
  SELECT ft.user_pseudo_id, ft.first_date, la.last_date
  FROM first_touch ft
  JOIN last_activity la USING (user_pseudo_id)
),
day_series AS (
  SELECT day_n FROM UNNEST(GENERATE_ARRAY(1, 60)) AS day_n
),
eligible AS (
  SELECT
    ds.day_n,
    DATE_DIFF(DATE('2021-01-31'), c.first_date, DAY) >= ds.day_n AS has_enough_runway,
    c.last_date >= DATE_ADD(c.first_date, INTERVAL ds.day_n DAY) AS retained
  FROM cohort c
  CROSS JOIN day_series ds
)
SELECT
  day_n,
  COUNTIF(has_enough_runway) AS eligible_users,
  COUNTIF(has_enough_runway AND retained) AS retained_users,
  ROUND(SAFE_DIVIDE(COUNTIF(has_enough_runway AND retained), COUNTIF(has_enough_runway)) * 100, 3) AS retention_pct
FROM eligible
GROUP BY day_n
ORDER BY day_n
