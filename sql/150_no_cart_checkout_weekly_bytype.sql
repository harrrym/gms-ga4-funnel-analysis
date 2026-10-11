-- 목적: "담기기록없음" 결제시작 유저를 주별로, "상품 0개"/"상품 있음"으로 나눠서 11월초 급증 원인을 분리.

WITH first_checkout_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_checkout_date,
    ARRAY_LENGTH(items) AS item_count
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
  COUNTIF(ac.user_pseudo_id IS NULL) AS no_cart_users,
  COUNTIF(ac.user_pseudo_id IS NULL AND (fc.item_count = 0 OR fc.item_count IS NULL)) AS no_cart_zero_items,
  COUNTIF(ac.user_pseudo_id IS NULL AND fc.item_count > 0) AS no_cart_has_items,
  ROUND(SAFE_DIVIDE(COUNTIF(ac.user_pseudo_id IS NULL AND (fc.item_count = 0 OR fc.item_count IS NULL)), COUNT(*)) * 100, 2) AS pct_zero_items,
  ROUND(SAFE_DIVIDE(COUNTIF(ac.user_pseudo_id IS NULL AND fc.item_count > 0), COUNT(*)) * 100, 2) AS pct_has_items_no_cartlog
FROM first_checkout_event fc
LEFT JOIN any_cart ac ON ac.user_pseudo_id = fc.user_pseudo_id
GROUP BY week_start
ORDER BY week_start
