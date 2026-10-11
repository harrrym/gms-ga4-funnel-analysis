-- 목적: 코호트별 퍼널 전환율 - 신규유저의 첫 방문 시간대(0~23시, UTC 기준)에 따라 7일 전환율이 다른지 확인.
-- 주의: event_timestamp은 UTC 기준이라 사용자의 실제 로컬 시간대와 다를 수 있음 (지역별 시간대 보정은 하지 않음).

WITH session_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    event_timestamp,
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
    MIN(event_date) AS first_date,
    MIN(TIMESTAMP_MICROS(event_timestamp)) AS first_ts
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
  EXTRACT(HOUR FROM ft.first_ts) AS hour_utc,
  COUNT(*) AS new_users,
  COUNTIF(fp.purchase_date IS NOT NULL AND DATE_DIFF(fp.purchase_date, ft.first_date, DAY) BETWEEN 0 AND 7) AS converted_7d,
  ROUND(SAFE_DIVIDE(
    COUNTIF(fp.purchase_date IS NOT NULL AND DATE_DIFF(fp.purchase_date, ft.first_date, DAY) BETWEEN 0 AND 7),
    COUNT(*)
  ) * 100, 3) AS conversion_rate_pct
FROM first_touch ft
LEFT JOIN first_purchase fp USING (user_pseudo_id)
GROUP BY hour_utc
ORDER BY hour_utc
