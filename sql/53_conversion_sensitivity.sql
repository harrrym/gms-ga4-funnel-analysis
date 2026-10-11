-- 목적: OMTM 주간 구매전환율(01번)이 revenue=0 구매 처리에 민감한지 확인한다.
-- 01번은 세션 단위 LOGICAL_OR(purchase)라 같은 세션 안의 중복 purchase에는 영향받지 않는다(중복 314건 전부 같은 세션).
-- 문서상 정책은 "전환율은 revenue=0 구매를 포함한 원본 유지"이고, 여기서는 revenue>0 구매만 인정했을 때
-- 문제구간의 급락 폭 결론이 뒤집히는지만 민감도 점검용으로 본다.

WITH session_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    event_name,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
sessions AS (
  SELECT
    DATE_TRUNC(event_date, WEEK(MONDAY)) AS week_start,
    CONCAT(user_pseudo_id, '-', CAST(session_id AS STRING)) AS session_key,
    LOGICAL_OR(event_name = 'purchase') AS purchased_raw,
    LOGICAL_OR(event_name = 'purchase' AND revenue > 0) AS purchased_valid
  FROM session_events
  WHERE session_id IS NOT NULL
  GROUP BY week_start, session_key
)
SELECT
  week_start,
  COUNT(*) AS sessions,
  COUNTIF(purchased_raw) AS purchase_sessions_raw,
  COUNTIF(purchased_valid) AS purchase_sessions_valid,
  ROUND(SAFE_DIVIDE(COUNTIF(purchased_raw), COUNT(*)) * 100, 3) AS conv_raw_pct,
  ROUND(SAFE_DIVIDE(COUNTIF(purchased_valid), COUNT(*)) * 100, 3) AS conv_valid_pct
FROM sessions
GROUP BY week_start
ORDER BY week_start
