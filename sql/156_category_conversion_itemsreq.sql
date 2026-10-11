-- 목적: 카테고리별 cart->checkout 전환율(143번)을 "상품>=1개 begin_checkout만 유효" 기준으로 재계산.
WITH first_cart_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_cart_date,
    items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp ASC) = 1
),
events AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    event_name,
    ARRAY_LENGTH(items) AS item_count
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
user_outcome AS (
  SELECT
    fc.user_pseudo_id,
    fc.first_cart_date,
    fc.items,
    MAX(CASE WHEN e.event_name = 'begin_checkout' AND e.item_count > 0 AND e.event_date >= fc.first_cart_date THEN 1 ELSE 0 END) AS did_checkout
  FROM first_cart_event fc
  LEFT JOIN events e ON e.user_pseudo_id = fc.user_pseudo_id
  GROUP BY fc.user_pseudo_id, fc.first_cart_date, fc.items
)
SELECT
  user_pseudo_id,
  CASE
    WHEN first_cart_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간'
    WHEN first_cart_date BETWEEN '2020-11-23' AND '2020-11-30' THEN '블프구간'
    WHEN first_cart_date < '2020-12-14' THEN '평상시'
    ELSE '사후구간'
  END AS period,
  item.item_category AS raw_category,
  did_checkout
FROM user_outcome, UNNEST(items) AS item
