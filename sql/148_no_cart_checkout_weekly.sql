-- 목적: "결제시작 유저 중 담기 기록 없는 비율"의 주별 추이. 급변 시점이 있으면 트래킹 변경 가능성 확인.

WITH first_checkout_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_checkout_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'begin_checkout'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp ASC) = 1
),
any_cart AS (
  SELECT DISTINCT user_pseudo_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
)
SELECT
  DATE_TRUNC(fc.first_checkout_date, WEEK(MONDAY)) AS week_start,
  COUNT(*) AS checkout_users,
  SUM(CASE WHEN ac.user_pseudo_id IS NULL THEN 1 ELSE 0 END) AS no_cart_users,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN ac.user_pseudo_id IS NULL THEN 1 ELSE 0 END), COUNT(*)) * 100, 2) AS no_cart_pct
FROM first_checkout_event fc
LEFT JOIN any_cart ac ON ac.user_pseudo_id = fc.user_pseudo_id
GROUP BY week_start
ORDER BY week_start
