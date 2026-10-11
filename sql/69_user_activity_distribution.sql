-- 목적: 봇·이상 활동 점검 ① - 유저(user_pseudo_id)별 활동량 분포.
-- 이벤트 수, 세션 수, 활동 일수의 분위수와 극단값 유저 수를 본다.

WITH e AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sid,
    event_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
u AS (
  SELECT
    user_pseudo_id,
    COUNT(*) AS events,
    COUNT(DISTINCT sid) AS sessions,
    COUNT(DISTINCT event_date) AS active_days
  FROM e
  GROUP BY user_pseudo_id
),
q AS (
  SELECT
    APPROX_QUANTILES(events, 1000) AS ev,
    APPROX_QUANTILES(sessions, 1000) AS se,
    APPROX_QUANTILES(active_days, 1000) AS ad
  FROM u
)
SELECT '이벤트 수/유저' AS metric, ev[OFFSET(500)] AS p50, ev[OFFSET(900)] AS p90, ev[OFFSET(990)] AS p99, ev[OFFSET(999)] AS p99_9, ev[OFFSET(1000)] AS max_val FROM q
UNION ALL
SELECT '세션 수/유저', se[OFFSET(500)], se[OFFSET(900)], se[OFFSET(990)], se[OFFSET(999)], se[OFFSET(1000)] FROM q
UNION ALL
SELECT '활동 일수/유저', ad[OFFSET(500)], ad[OFFSET(900)], ad[OFFSET(990)], ad[OFFSET(999)], ad[OFFSET(1000)] FROM q
UNION ALL
SELECT '전체 유저 수', COUNT(*), NULL, NULL, NULL, NULL FROM u
UNION ALL
SELECT '이벤트 500개 이상 유저 수', COUNTIF(events >= 500), NULL, NULL, NULL, NULL FROM u
UNION ALL
SELECT '이벤트 1000개 이상 유저 수', COUNTIF(events >= 1000), NULL, NULL, NULL, NULL FROM u
UNION ALL
SELECT '세션 50개 이상 유저 수', COUNTIF(sessions >= 50), NULL, NULL, NULL, NULL FROM u
UNION ALL
SELECT '세션 100개 이상 유저 수', COUNTIF(sessions >= 100), NULL, NULL, NULL, NULL FROM u
