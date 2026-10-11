-- 목적: cart->checkout을 "상품이 1개 이상 들어있는 begin_checkout"만 성공으로 재계산.
-- 기존(아무 begin_checkout이나 성공)과 나란히 비교하고, "상품 0개 결제시작" 비율도 기간별로 본다.

WITH first_cart_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_cart_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp ASC) = 1
),
checkout_events AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    ARRAY_LENGTH(items) AS item_count
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'begin_checkout'
),
user_outcome AS (
  SELECT
    fc.user_pseudo_id,
    fc.first_cart_date,
    MAX(CASE WHEN ce.event_date >= fc.first_cart_date THEN 1 ELSE 0 END) AS did_checkout_any,
    MAX(CASE WHEN ce.event_date >= fc.first_cart_date AND ce.item_count > 0 THEN 1 ELSE 0 END) AS did_checkout_with_items
  FROM first_cart_event fc
  LEFT JOIN checkout_events ce ON ce.user_pseudo_id = fc.user_pseudo_id
  GROUP BY fc.user_pseudo_id, fc.first_cart_date
),
labeled AS (
  SELECT
    *,
    CASE
      WHEN first_cart_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간'
      WHEN first_cart_date BETWEEN '2020-11-23' AND '2020-11-30' THEN '블프구간'
      WHEN first_cart_date < '2020-12-14' THEN '평상시'
      ELSE '사후구간'
    END AS period
  FROM user_outcome
)
SELECT
  period,
  COUNT(*) AS cart_users,
  SUM(did_checkout_any) AS checkout_any_users,
  SUM(did_checkout_with_items) AS checkout_with_items_users,
  SUM(CASE WHEN did_checkout_any = 1 AND did_checkout_with_items = 0 THEN 1 ELSE 0 END) AS checkout_zero_items_only_users,
  ROUND(SAFE_DIVIDE(SUM(did_checkout_any), COUNT(*)) * 100, 2) AS cart_to_checkout_any_rate,
  ROUND(SAFE_DIVIDE(SUM(did_checkout_with_items), COUNT(*)) * 100, 2) AS cart_to_checkout_withitems_rate,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN did_checkout_any = 1 AND did_checkout_with_items = 0 THEN 1 ELSE 0 END), SUM(did_checkout_any)) * 100, 2) AS pct_zero_item_checkout_among_checkouters
FROM labeled
GROUP BY period
ORDER BY period
