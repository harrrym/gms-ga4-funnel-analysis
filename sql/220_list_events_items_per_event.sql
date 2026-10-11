-- 목적: H2/H3 검증용 - 하위기간·경로별 view_item 이벤트 수와 아이템 수 합 (목록당 노출 상품 수 계산용, 아이템 6개 이상 이벤트). sql/219와 같은 하위기간.
SELECT
  CASE WHEN d <= '2020-12-13' THEN 'P0' WHEN d <= '2020-12-18' THEN 'P1' WHEN d <= '2020-12-28' THEN 'P2'
       WHEN d <= '2021-01-11' THEN 'P3' WHEN d <= '2021-01-18' THEN 'P4' ELSE 'P5' END AS sub,
  path, COUNT(*) AS list_events, SUM(n_items) AS total_items
FROM (
  SELECT PARSE_DATE('%Y%m%d', event_date) AS d, ARRAY_LENGTH(items) AS n_items,
    LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131' AND event_name = 'view_item' AND ARRAY_LENGTH(items) >= 1
)
WHERE path IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html') GROUP BY sub, path
