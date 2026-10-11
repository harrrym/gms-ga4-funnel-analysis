-- 목적: 봇·이상 활동 점검 ④ - 주간 세션의 질(이벤트 2개 이하 세션 비중, 신규 세션 비중)과
-- "이벤트 2개 이하 세션"을 분모에서 뺐을 때의 전환율을 본다. OMTM 급락 구간(12/28~1/04)의 세션 증가가 무의미한 방문 때문인지 확인.
-- 세션 정의는 01번 쿼리와 동일하게 (week, user, session_id) 단위.

WITH sess AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week_start,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sid,
    MAX((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number')) AS session_number,
    COUNT(*) AS events,
    COUNTIF(event_name = 'user_engagement') AS eng_events,
    LOGICAL_OR(event_name = 'purchase') AS purchased
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  GROUP BY week_start, user_pseudo_id, sid
)
SELECT
  week_start,
  COUNT(*) AS sessions,
  COUNTIF(session_number = 1) AS new_sessions,
  COUNTIF(events <= 2) AS sessions_le2_events,
  ROUND(COUNTIF(events <= 2) * 100 / COUNT(*), 1) AS pct_le2_events,
  ROUND(COUNTIF(eng_events = 0) * 100 / COUNT(*), 1) AS pct_no_engagement,
  COUNTIF(purchased) AS purchase_sessions,
  ROUND(COUNTIF(purchased) * 100 / COUNT(*), 3) AS conv_all_pct,
  ROUND(COUNTIF(purchased) * 100 / COUNTIF(events > 2), 3) AS conv_excl_le2_pct
FROM sess
GROUP BY week_start
ORDER BY week_start
