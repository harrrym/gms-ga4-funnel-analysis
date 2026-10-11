-- 목적: 담기기록 없이 구매한 유저 중, 첫 방문(user_first_touch_timestamp)이 관측 시작(11/1) 이후인
-- 비율을 주별로 확인 - 관측 윈도우 밖에서 담았을 가능성 vs 순수 로깅 누락을 구분.

WITH first_purchase_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_purchase_date,
    user_first_touch_timestamp
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp ASC) = 1
),
any_cart AS (
  SELECT DISTINCT user_pseudo_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
),
no_cart_purchasers AS (
  SELECT
    fp.user_pseudo_id,
    fp.first_purchase_date,
    TIMESTAMP_MICROS(fp.user_first_touch_timestamp) AS first_touch_ts
  FROM first_purchase_event fp
  LEFT JOIN any_cart ac ON ac.user_pseudo_id = fp.user_pseudo_id
  WHERE ac.user_pseudo_id IS NULL
)
SELECT
  DATE_TRUNC(first_purchase_date, WEEK(MONDAY)) AS week_start,
  COUNT(*) AS no_cart_purchasers,
  COUNTIF(first_touch_ts >= TIMESTAMP('2020-11-01 00:00:00 UTC')) AS first_touch_within_window,
  ROUND(SAFE_DIVIDE(COUNTIF(first_touch_ts >= TIMESTAMP('2020-11-01 00:00:00 UTC')), COUNT(*)) * 100, 2) AS pct_first_touch_within_window,
  COUNTIF(first_touch_ts IS NULL) AS first_touch_null
FROM no_cart_purchasers
GROUP BY week_start
ORDER BY week_start
