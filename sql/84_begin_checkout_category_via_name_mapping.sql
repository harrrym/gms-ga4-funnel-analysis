-- 목적: begin_checkout의 item_category가 너무 굵은 단위라 세부 비교가 안 되는 문제 해결.
-- add_to_cart 이벤트에는 같은 상품(item_name)에 대해 훨씬 세분화된 item_category가 찍혀 있으므로,
-- item_name -> 세분화된 category 매핑 테이블을 add_to_cart에서 만들어 begin_checkout에 역으로 붙인다.

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
  -- 상품명 하나에 카테고리가 여러 개 찍혀 있을 수 있으니(라벨 불일치), 빈 값을 제외하고 가장 흔한(최빈값) 카테고리를 대표로 선택
  SELECT
    item_name,
    ARRAY_AGG(category ORDER BY n DESC, category LIMIT 1)[OFFSET(0)] AS category
  FROM cart_category_counts
  GROUP BY item_name
),
begin_checkout_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'begin_checkout'
),
labeled AS (
  SELECT
    CASE WHEN bc.event_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '평상시' END AS period,
    item.item_name AS item_name,
    item.item_category AS native_category,
    m.category AS mapped_category,
    item.price AS price
  FROM begin_checkout_events bc, UNNEST(items) AS item
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
