-- 목적: H2/H3 검증용 - 목록 경로 view_item(아이템 6개 이상)에 노출된 상품의 (날짜, 경로, 상품, 가격)별 노출 수. 12/1~1/31.
-- 하위기간(P0~P5)은 파이썬에서 날짜로 나눔(품절 추정 시점이 날짜별이라 일별로 뽑음).
-- 하위기간은 view_item 기록 변화 시점(12/29, 1/19)을 기준으로 나눔: P0 12/1~12/13, P1 12/14~12/18, P2 12/19~12/28, P3 12/29~1/11, P4 1/12~1/18, P5 1/19~1/31.
SELECT
  d, path, item_id, ANY_VALUE(item_name) AS item_name, price, COUNT(*) AS impressions
FROM (
  SELECT PARSE_DATE('%Y%m%d', event_date) AS d,
    LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path,
    item.item_id AS item_id, item.item_name AS item_name, item.price AS price
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131' AND event_name = 'view_item' AND ARRAY_LENGTH(items) >= 6
)
WHERE path IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')
GROUP BY d, path, item_id, price
