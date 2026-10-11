-- 목적: H4b 점검 - 일별 이벤트 수와 비율: page_view 대비 view_item, page_view 대비 add_to_cart (12/1~1/31).
-- 기록 방식이 바뀌면 이벤트 수 비율이 계단식으로 달라진다. view_item은 목록 경로(아이템 있음)와 그 외 경로(상세, 아이템 0개)로, add_to_cart는 quantity>0 여부로 나눠 집계.
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS d,
  COUNTIF(event_name = 'page_view') AS page_view,
  COUNTIF(event_name = 'page_view' AND LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')) AS page_view_list,
  COUNTIF(event_name = 'view_item') AS view_item,
  COUNTIF(event_name = 'view_item' AND ARRAY_LENGTH(items) > 0) AS view_item_with_items,
  COUNTIF(event_name = 'view_item' AND ARRAY_LENGTH(items) = 0) AS view_item_zero_items,
  COUNTIF(event_name = 'add_to_cart') AS add_to_cart,
  COUNTIF(event_name = 'add_to_cart' AND EXISTS(SELECT 1 FROM UNNEST(items) i WHERE i.quantity IS NOT NULL AND i.quantity > 0)) AS add_to_cart_qpos,
  COUNTIF(event_name = 'begin_checkout') AS begin_checkout,
  COUNTIF(event_name = 'select_item') AS select_item
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131'
GROUP BY d ORDER BY d
