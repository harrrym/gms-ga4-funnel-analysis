-- 목적: 1월 말 Dino Game Tee 상세 페이지 유입이 ①(방문->목록 노출)과 ①+②(방문->담기)를 낮췄는지 확인 (12/1~1/31).
-- 세션을 (랜딩이 상세 페이지인지, 랜딩이 Dino Game Tee인지, 세션 중 Dino Game Tee 페이지를 본 적 있는지)로 나눠 단계별 세션 수를 일별로 집계.
-- 랜딩 = 세션의 첫 page_view 경로. 상세 = /google+redesign/ 아래이면서 목록 경로(sql/202 집합)가 아닌 경로. 단계 정의는 sql/207과 동일.
WITH ev AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    PARSE_DATE('%Y%m%d', event_date) AS event_date, event_name, event_timestamp,
    LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131'
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
),
s AS (
  SELECT session_key, MIN(event_date) AS session_date,
    ARRAY_AGG(IF(event_name = 'page_view', path, NULL) IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS landing_path,
    LOGICAL_OR(path LIKE '%dino+game+tee%') AS any_dino,
    LOGICAL_OR(event_name = 'view_item' AND path IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')) AS view_on_list,
    LOGICAL_OR(event_name = 'add_to_cart') AS has_cart,
    LOGICAL_OR(event_name = 'begin_checkout') AS has_checkout,
    LOGICAL_OR(event_name = 'purchase') AS has_purchase
  FROM ev GROUP BY session_key
)
SELECT session_date,
  (landing_path LIKE '/google+redesign/%' AND landing_path NOT IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')) AS landing_detail,
  (landing_path LIKE '%google+dino+game+tee') AS landing_dino,
  any_dino,
  COUNT(*) AS s0_sessions,
  COUNTIF(view_on_list OR has_cart OR has_checkout OR has_purchase) AS s1_list_exposed,
  COUNTIF(has_cart OR has_checkout OR has_purchase) AS s2_cart_reached,
  COUNTIF(has_purchase) AS s4_purchase
FROM s GROUP BY session_date, landing_detail, landing_dino, any_dino
