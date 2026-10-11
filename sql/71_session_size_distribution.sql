-- 목적: 봇·이상 활동 점검 ③ - 세션별 이벤트 수 분포와 극단 세션 수.
-- 한 세션 안에 이벤트가 비정상적으로 많거나(자동화 의심), 이벤트가 1~2개뿐인 세션(무의미한 방문)이 얼마나 되는지 본다.

WITH sess AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sid,
    COUNT(*) AS events,
    COUNTIF(event_name = 'user_engagement') AS eng_events,
    COUNTIF(event_name = 'page_view') AS page_views,
    LOGICAL_OR(event_name = 'purchase') AS purchased
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  GROUP BY user_pseudo_id, sid
),
q AS (SELECT APPROX_QUANTILES(events, 1000) AS ev FROM sess)
SELECT '세션당 이벤트 수 (p50 / p90 / p99 / p99.9 / max)' AS metric,
       ev[OFFSET(500)] AS v1, ev[OFFSET(900)] AS v2, ev[OFFSET(990)] AS v3, ev[OFFSET(999)] AS v4, ev[OFFSET(1000)] AS v5
FROM q
UNION ALL
SELECT '전체 세션 수', COUNT(*), NULL, NULL, NULL, NULL FROM sess
UNION ALL
SELECT '이벤트 100개 이상 세션 수', COUNTIF(events >= 100), NULL, NULL, NULL, NULL FROM sess
UNION ALL
SELECT '이벤트 300개 이상 세션 수', COUNTIF(events >= 300), NULL, NULL, NULL, NULL FROM sess
UNION ALL
SELECT '이벤트 1000개 이상 세션 수', COUNTIF(events >= 1000), NULL, NULL, NULL, NULL FROM sess
UNION ALL
SELECT '이벤트 2개 이하 세션 수', COUNTIF(events <= 2), NULL, NULL, NULL, NULL FROM sess
UNION ALL
SELECT '참여(user_engagement) 없는 세션 수', COUNTIF(eng_events = 0), NULL, NULL, NULL, NULL FROM sess
UNION ALL
SELECT '이벤트 300개 이상 세션 중 구매 세션 수', COUNTIF(events >= 300 AND purchased), NULL, NULL, NULL, NULL FROM sess
