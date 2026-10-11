-- 목적: Retention 단계 - 신규유저(첫 세션 기준) 주간 코호트별 "재방문" 롤링 리텐션(Day 7/14/30).
-- 롤링 리텐션: "정확히 N일째"가 아니라 "N일째 또는 그 이후 아무 때나 다시 활동했는가"를 본다.
-- 주의(censoring): 데이터가 2021-01-31에 끝나므로, 첫 세션으로부터 N일을 관찰할 시간이
-- 실제로 없었던 코호트는 분모(eligible_users)에서 제외한다(has_enough_runway로 필터링).
-- "재방문"의 기준은 구매 여부와 무관한 모든 이벤트(세션) 발생이다.

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
  SELECT
    user_pseudo_id,
    MIN(event_date) AS first_date
  FROM events
  WHERE session_number = 1 AND session_id IS NOT NULL
  GROUP BY user_pseudo_id
),
last_activity AS (
  SELECT
    user_pseudo_id,
    MAX(event_date) AS last_date
  FROM events
  GROUP BY user_pseudo_id
),
cohort AS (
  SELECT
    ft.user_pseudo_id,
    ft.first_date,
    DATE_TRUNC(ft.first_date, WEEK(MONDAY)) AS cohort_week,
    la.last_date
  FROM first_touch ft
  JOIN last_activity la USING (user_pseudo_id)
),
checkpoints AS (
  SELECT 7 AS day_n UNION ALL SELECT 14 UNION ALL SELECT 30
),
cohort_size AS (
  SELECT cohort_week, COUNT(*) AS cohort_size
  FROM cohort
  GROUP BY cohort_week
),
eligible AS (
  SELECT
    c.cohort_week,
    ck.day_n,
    DATE_DIFF(DATE('2021-01-31'), c.first_date, DAY) >= ck.day_n AS has_enough_runway,
    c.last_date >= DATE_ADD(c.first_date, INTERVAL ck.day_n DAY) AS retained
  FROM cohort c
  CROSS JOIN checkpoints ck
)
SELECT
  e.cohort_week,
  cs.cohort_size,
  e.day_n,
  COUNTIF(e.has_enough_runway) AS eligible_users,
  COUNTIF(e.has_enough_runway AND e.retained) AS retained_users,
  ROUND(SAFE_DIVIDE(COUNTIF(e.has_enough_runway AND e.retained), COUNTIF(e.has_enough_runway)) * 100, 2) AS retention_pct
FROM eligible e
JOIN cohort_size cs USING (cohort_week)
GROUP BY e.cohort_week, cs.cohort_size, e.day_n
ORDER BY e.cohort_week, e.day_n
