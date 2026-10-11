-- 목적: 구매 카테고리 비중(item_name 매핑 방법론)을 평상시 정의 v3로 재계산.
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
    CASE
      WHEN p.event_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간'
      WHEN p.event_date BETWEEN '2020-12-01' AND '2020-12-13' THEN '평상시'
      ELSE '사후구간'
    END AS period,
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
