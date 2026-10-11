-- 목적: 코호트별 퍼널 전환율 - 신규유저의 첫 방문 요일에 따라 7일 전환율이 다른지 확인한다.

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
first_touch AS (
  SELECT
    user_pseudo_id,
    MIN(event_date) AS first_date
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
  FORMAT_DATE('%A', ft.first_date) AS weekday,
  EXTRACT(DAYOFWEEK FROM ft.first_date) AS weekday_num,
  COUNT(*) AS new_users,
  COUNTIF(fp.purchase_date IS NOT NULL AND DATE_DIFF(fp.purchase_date, ft.first_date, DAY) BETWEEN 0 AND 7) AS converted_7d,
  ROUND(SAFE_DIVIDE(
    COUNTIF(fp.purchase_date IS NOT NULL AND DATE_DIFF(fp.purchase_date, ft.first_date, DAY) BETWEEN 0 AND 7),
    COUNT(*)
  ) * 100, 3) AS conversion_rate_pct
FROM first_touch ft
LEFT JOIN first_purchase fp USING (user_pseudo_id)
GROUP BY weekday, weekday_num
ORDER BY weekday_num
