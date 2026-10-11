-- 목적: 이벤트 유형별 items 필드 채움 비율과 이벤트당 아이템 수 (12/1~1/11). 상품 단위 분석 가능 여부 판단.
WITH it AS (
  SELECT event_name, ARRAY_LENGTH(items) AS n_items, item
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210111'
    AND event_name IN ('view_item', 'select_item', 'add_to_cart', 'begin_checkout', 'purchase')
)
SELECT
  event_name,
  COUNT(*) AS item_rows,
  ROUND(AVG(n_items), 2) AS avg_items_per_event,
  ROUND(100 * COUNTIF(item.item_id IS NOT NULL AND item.item_id != '(not set)') / COUNT(*), 1) AS pct_item_id,
  ROUND(100 * COUNTIF(item.price IS NOT NULL AND item.price > 0) / COUNT(*), 1) AS pct_price,
  ROUND(100 * COUNTIF(item.quantity IS NOT NULL AND item.quantity > 0) / COUNT(*), 1) AS pct_quantity_gt0,
  ROUND(100 * COUNTIF(item.item_list_index IS NOT NULL AND item.item_list_index != '(not set)') / COUNT(*), 1) AS pct_list_index,
  ROUND(100 * COUNTIF(item.item_list_name IS NOT NULL AND item.item_list_name != '(not set)') / COUNT(*), 1) AS pct_list_name,
  ROUND(100 * COUNTIF(item.item_list_id IS NOT NULL AND item.item_list_id != '(not set)') / COUNT(*), 1) AS pct_list_id,
  ROUND(100 * COUNTIF(item.item_revenue IS NOT NULL AND item.item_revenue > 0) / COUNT(*), 1) AS pct_item_revenue,
  ROUND(100 * COUNTIF(item.item_variant IS NOT NULL AND item.item_variant != '(not set)') / COUNT(*), 1) AS pct_variant
FROM it GROUP BY event_name ORDER BY event_name
