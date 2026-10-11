-- 목적: "담기 기록 없이 결제시작"인 유저의 begin_checkout 이벤트에 실제로 items(상품)가 들어있는지 확인.
-- items가 비어있으면 진짜 "빈 장바구니로 결제시작"이고, items가 차있으면 add_to_cart 로깅만 빠진 것.

WITH first_checkout_event AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
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
  CASE WHEN ac.user_pseudo_id IS NULL THEN '담기기록없음' ELSE '담기기록있음' END AS cart_log_status,
  COUNT(*) AS users,
  COUNTIF(fc.item_count = 0 OR fc.item_count IS NULL) AS checkout_with_zero_items,
  ROUND(AVG(fc.item_count), 2) AS avg_item_count,
  MIN(fc.item_count) AS min_item_count,
  MAX(fc.item_count) AS max_item_count
FROM first_checkout_event fc
LEFT JOIN any_cart ac ON ac.user_pseudo_id = fc.user_pseudo_id
GROUP BY cart_log_status
