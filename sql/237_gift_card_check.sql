-- 목적: 2020~21 스토어에 기프트카드가 이미 있었는지 확인 - 기프트카드 상품(상품명에 gift card 포함)의 구매·담기와 /gift+card 경로 page_view. 11/1~1/31.
SELECT 'purchase_item' AS kind, LOWER(TRIM(item.item_name)) AS name, PARSE_DATE('%Y%m%d', event_date) AS d, SUM(item.quantity) AS n, COUNT(DISTINCT ecommerce.transaction_id) AS orders
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131' AND event_name = 'purchase' AND LOWER(item.item_name) LIKE '%gift card%'
GROUP BY name, d
UNION ALL
SELECT 'cart_item', LOWER(TRIM(item.item_name)), PARSE_DATE('%Y%m%d', event_date), SUM(item.quantity), COUNT(DISTINCT user_pseudo_id)
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131' AND event_name = 'add_to_cart' AND LOWER(item.item_name) LIKE '%gift card%'
GROUP BY 2, 3
UNION ALL
SELECT 'page_view_giftcard_path', LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')),
  PARSE_DATE('%Y%m%d', event_date), COUNT(*), COUNT(DISTINCT user_pseudo_id)
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131' AND event_name = 'page_view'
  AND LOWER((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location')) LIKE '%gift%card%'
GROUP BY 2, 3
