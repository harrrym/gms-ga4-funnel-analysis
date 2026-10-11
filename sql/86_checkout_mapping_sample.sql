-- 목적: 84번에서 한 item_name -> category 매핑이 실제로 어떻게 됐는지 샘플로 확인.
-- 결제시작 상품의 원래(굵은) 카테고리와, add_to_cart에서 가져온 매핑된(세분화된) 카테고리를 나란히 보여준다.

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
checkout_items AS (
  SELECT DISTINCT
    item.item_name AS item_name,
    item.item_category AS native_category,
    item.price AS price
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'begin_checkout'
    AND item.item_name IS NOT NULL
)
SELECT
  ci.item_name,
  ci.native_category AS checkout_native_category,
  m.category AS mapped_fine_category,
  ci.price
FROM checkout_items ci
LEFT JOIN cart_name_to_category m ON m.item_name = ci.item_name
ORDER BY RAND()
LIMIT 15
