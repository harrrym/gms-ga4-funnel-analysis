-- 목적: 담김 카테고리 비중(81번, 첫 add_to_cart 이벤트 기준)을 블랙프라이데이 주 제외 기준으로 재계산.
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
labeled AS (
  SELECT
    CASE
      WHEN first_cart_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간'
      WHEN first_cart_date BETWEEN '2020-11-23' AND '2020-11-30' THEN '블프구간'
      ELSE '평상시(블프제외)'
    END AS period,
    item.item_category AS category,
    item.price AS price
  FROM first_cart_event, UNNEST(items) AS item
)
SELECT
  period,
  category,
  COUNT(*) AS item_adds,
  ROUND(AVG(price), 2) AS avg_price,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY period), 2) AS pct_of_period_item_adds
FROM labeled
GROUP BY period, category
ORDER BY period, item_adds DESC
