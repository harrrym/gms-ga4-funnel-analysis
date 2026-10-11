-- 목적: (a) item_list_name 값 분포, (b) 주별 add_to_cart 이벤트 중 quantity>0 아이템이 있는 비율, (c) 목록 페이지 경로와 items의 item_category 일치 여부.
SELECT 'list_name' AS kind, event_name AS k1, COALESCE(item.item_list_name, '(null)') AS k2, COUNT(*) AS n
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210111' AND event_name IN ('view_item', 'add_to_cart', 'begin_checkout', 'purchase')
GROUP BY k1, k2
QUALIFY ROW_NUMBER() OVER (PARTITION BY k1 ORDER BY COUNT(*) DESC) <= 8

UNION ALL

SELECT 'weekly_qty_event' AS kind,
  CAST(DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS STRING) AS k1,
  'events_with_qty_item' AS k2,
  COUNTIF((SELECT COUNT(1) FROM UNNEST(items) i WHERE i.quantity IS NOT NULL AND i.quantity > 0) >= 1) AS n
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201116' AND '20210131' AND event_name = 'add_to_cart'
GROUP BY k1

UNION ALL

SELECT 'weekly_qty_event', CAST(DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS STRING), 'events_total', COUNT(*)
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201116' AND '20210131' AND event_name = 'add_to_cart'
GROUP BY 2

UNION ALL

SELECT 'path_vs_item_category',
  REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)') AS k1,
  COALESCE(item.item_category, '(null)') AS k2, COUNT(*) AS n
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210111' AND event_name = 'view_item'
  AND REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')
      IN ('/Google+Redesign/Apparel/Hats', '/Google+Redesign/Apparel/Mens', '/Google+Redesign/Stationery/Notebooks', '/Google+Redesign/Clearance')
GROUP BY k1, k2
