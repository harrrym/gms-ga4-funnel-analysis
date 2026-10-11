-- 목적: 검색 사용 여부와 7일 전환율의 관계가 주(코호트)별로 안정적인지 확인한다.
-- 특히 OMTM 문제구간(12/28~1/4)에도 이 관계가 유지되는지가 관심사.

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
  DATE_TRUNC(fsb.first_date, WEEK(MONDAY)) AS week_start,
  fsb.did_search,
  COUNT(*) AS users,
  COUNTIF(fp.purchase_date IS NOT NULL AND DATE_DIFF(fp.purchase_date, fsb.first_date, DAY) BETWEEN 0 AND 7) AS converted_7d,
  ROUND(SAFE_DIVIDE(
    COUNTIF(fp.purchase_date IS NOT NULL AND DATE_DIFF(fp.purchase_date, fsb.first_date, DAY) BETWEEN 0 AND 7),
    COUNT(*)
  ) * 100, 3) AS conversion_rate_pct
FROM first_session_behavior fsb
LEFT JOIN first_purchase fp USING (user_pseudo_id)
GROUP BY week_start, fsb.did_search
ORDER BY week_start, fsb.did_search
