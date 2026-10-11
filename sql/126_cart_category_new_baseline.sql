-- 목적: 담김 카테고리 비중(76/113번과 동일 방법론)을 새 평상시 정의로 재계산.
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
      WHEN first_cart_date < '2020-12-14' THEN '평상시'
      ELSE '사후구간'
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
