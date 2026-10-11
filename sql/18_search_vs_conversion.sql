-- 목적: Activation 재정의. "첫 세션 검색 사용"이 리텐션이 아니라 "7일 이내 구매전환"과
-- 관련 있는지 확인한다 (GMS는 저빈도 구매 서비스라 습관형 리텐션보다 전환이 더 적합한 종속변수).

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
first_purchase AS (
  SELECT
    user_pseudo_id,
    MIN(event_date) AS purchase_date
  FROM session_events
  WHERE event_name = 'purchase'
  GROUP BY user_pseudo_id
)
SELECT
  fsb.did_search,
  COUNT(*) AS users,
  COUNTIF(fp.purchase_date IS NOT NULL AND DATE_DIFF(fp.purchase_date, fsb.first_date, DAY) BETWEEN 0 AND 7) AS converted_7d,
  ROUND(SAFE_DIVIDE(
    COUNTIF(fp.purchase_date IS NOT NULL AND DATE_DIFF(fp.purchase_date, fsb.first_date, DAY) BETWEEN 0 AND 7),
    COUNT(*)
  ) * 100, 3) AS conversion_rate_pct
FROM first_session_behavior fsb
LEFT JOIN first_purchase fp USING (user_pseudo_id)
GROUP BY fsb.did_search
