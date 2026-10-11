-- 목적: 전체 ②(목록 노출 도달 세션 중 담기 도달)의 분모(s1)를 구성별로 나눠 1월 말 하락이 어디서 오는지 확인 (12/1~1/31, 일별).
-- g1 = 목록 경로(sql/202의 경로 집합)에서 view_item이 있는 세션, g2 = view_item은 있으나 목록 경로가 아닌 곳에서만, g3 = view_item 없이 담기 이후 단계만 있는 세션.
-- 각 그룹의 s2_all = 세션에 add_to_cart/begin_checkout/purchase가 하나라도 있는 세션 (sql/191과 동일 정의).
WITH ev AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    PARSE_DATE('%Y%m%d', event_date) AS event_date, event_name,
    LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131'
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
),
s AS (
  SELECT session_key, MIN(event_date) AS session_date,
    LOGICAL_OR(event_name = 'view_item' AND path IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')) AS view_on_list,
    LOGICAL_OR(event_name = 'view_item') AS view_any,
    LOGICAL_OR(event_name IN ('add_to_cart', 'begin_checkout', 'purchase')) AS s2,
    LOGICAL_OR(event_name = 'add_to_cart' AND path IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')) AS cart_on_list
  FROM ev GROUP BY session_key
)
SELECT session_date,
  CASE WHEN view_on_list THEN 'g1_목록경로 노출' WHEN view_any THEN 'g2_그외경로 노출' WHEN s2 THEN 'g3_노출없이 담기이후' ELSE 'x' END AS grp,
  COUNT(*) AS sessions, COUNTIF(s2) AS s2_sessions, COUNTIF(cart_on_list) AS cart_on_list_sessions
FROM s WHERE view_any OR s2 GROUP BY session_date, grp
