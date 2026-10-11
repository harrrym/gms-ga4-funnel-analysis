-- 목적: 가격 4분위 vs 전환율(89/116번과 동일 방법론)을 새 평상시 정의로 재계산.
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
user_price AS (
  SELECT
    user_pseudo_id,
    first_cart_date,
    SAFE_DIVIDE(
      SUM(item.price * IFNULL(item.quantity, 1)),
      SUM(IFNULL(item.quantity, 1))
    ) AS cart_weighted_avg_price
  FROM first_cart_event, UNNEST(items) AS item
  WHERE item.price IS NOT NULL
  GROUP BY user_pseudo_id, first_cart_date
),
events AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
user_outcome AS (
  SELECT
    up.user_pseudo_id,
    up.first_cart_date,
    up.cart_weighted_avg_price,
    MAX(CASE WHEN e.event_name = 'begin_checkout' AND e.event_date >= up.first_cart_date THEN 1 ELSE 0 END) AS did_checkout
  FROM user_price up
  LEFT JOIN events e ON e.user_pseudo_id = up.user_pseudo_id
  GROUP BY up.user_pseudo_id, up.first_cart_date, up.cart_weighted_avg_price
),
labeled AS (
  SELECT
    *,
    CASE
      WHEN first_cart_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간'
      WHEN first_cart_date BETWEEN '2020-11-23' AND '2020-11-30' THEN '블프구간'
      WHEN first_cart_date < '2020-12-14' THEN '평상시'
      ELSE '사후구간'
    END AS period,
    NTILE(4) OVER (ORDER BY cart_weighted_avg_price) AS price_tier
  FROM user_outcome
)
SELECT
  price_tier,
  period,
  COUNT(*) AS users,
  SUM(did_checkout) AS checkout_users,
  ROUND(SAFE_DIVIDE(SUM(did_checkout), COUNT(*)) * 100, 2) AS cart_to_checkout_rate
FROM labeled
GROUP BY price_tier, period
ORDER BY price_tier, period
