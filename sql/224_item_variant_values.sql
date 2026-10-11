-- 목적: items.item_variant에 사이즈 정보가 있는지 확인 - 이벤트별 채움 비율과 purchase 상위 값 (12/1~1/31).
SELECT 'fill' AS kind, event_name AS k1, CAST(NULL AS STRING) AS k2, COUNT(*) AS n,
  COUNTIF(item.item_variant IS NOT NULL AND item.item_variant != '(not set)') AS n2
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131' AND event_name IN ('view_item', 'add_to_cart', 'begin_checkout', 'purchase')
GROUP BY event_name
UNION ALL
SELECT 'purchase_variant', 'purchase', item.item_variant, SUM(item.quantity), COUNT(*)
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131' AND event_name = 'purchase'
GROUP BY item.item_variant
