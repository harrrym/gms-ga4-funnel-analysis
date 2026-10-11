-- 목적: 84번 매핑에 상품명 키워드 교차검증을 추가하기 위해, 결제시작 상품의 개별 행(그룹핑 안 함)을 뽑는다.
-- period, item_name, 원본카테고리, add_to_cart 기반 매핑카테고리, price를 그대로 반환 -> 파이썬에서 키워드 규칙 적용.

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
begin_checkout_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'begin_checkout'
)
SELECT
  CASE WHEN bc.event_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '평상시' END AS period,
  item.item_name AS item_name,
  item.item_category AS native_category,
  m.category AS mode_mapped_category,
  item.price AS price
FROM begin_checkout_events bc, UNNEST(items) AS item
LEFT JOIN cart_name_to_category m ON m.item_name = item.item_name
WHERE item.item_name IS NOT NULL
