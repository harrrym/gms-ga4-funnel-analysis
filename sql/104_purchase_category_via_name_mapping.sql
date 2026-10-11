-- 목적: purchase의 item_category도 begin_checkout과 마찬가지로 뭉뚱그려진 단위라(103번으로 확인),
-- add_to_cart 기반 item_name -> 세분화된 category 매핑을 purchase에도 동일하게 적용한다. (84번과 동일 방법론)

WITH cart_category_counts AS (
  SELECT
    item.item_name AS item_name,
    item.item_category AS category,
    COUNT(*) AS n
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
    AND item.item_name IS NOT NULL
    AND item.item_category IS NOT NULL
    AND item.item_category != ''
  GROUP BY item.item_name, item.item_category
),
cart_name_to_category AS (
  SELECT
    item_name,
    ARRAY_AGG(category ORDER BY n DESC, category LIMIT 1)[OFFSET(0)] AS category
  FROM cart_category_counts
  GROUP BY item_name
),
purchase_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),
labeled AS (
  SELECT
    CASE WHEN p.event_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '평상시' END AS period,
    item.item_name AS item_name,
    item.item_category AS native_category,
    m.category AS mapped_category,
    item.price AS price
  FROM purchase_events p, UNNEST(items) AS item
  LEFT JOIN cart_name_to_category m ON m.item_name = item.item_name
)
SELECT
  period,
  COALESCE(mapped_category, native_category) AS category,
  COUNT(*) AS item_count,
  SUM(CASE WHEN mapped_category IS NULL THEN 1 ELSE 0 END) AS unmapped_count,
  ROUND(AVG(price), 2) AS avg_price,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY period), 2) AS pct_of_period_items
FROM labeled
GROUP BY period, category
ORDER BY period, item_count DESC
