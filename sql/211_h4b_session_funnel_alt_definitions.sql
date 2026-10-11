-- 목적: H4b(기록 방식 변화) 점검 - ①을 page_view 기준으로, 담기를 quantity>0 기준으로 다시 세고 (12/1~1/31, 일별), q>0/q=0 담기 세션의 결제시작 도달률 비교.
-- s1_view = 목록 경로 view_item 또는 이후 단계(sql/207) / s1_pv = 목록 경로 page_view 또는 이후 단계 / s2 = 담기 도달(기존)
-- s2q_cum = quantity>0 아이템이 있는 add_to_cart 또는 이후 단계(begin_checkout|purchase) / s2q_only = quantity>0 담기 세션만
-- c_q_* = quantity>0 담기가 있는 세션, c_q0_* = add_to_cart가 있지만 quantity>0 아이템이 있는 담기는 없는 세션: 세션 수, 같은 세션 결제시작·구매 도달 수
WITH ev AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    PARSE_DATE('%Y%m%d', event_date) AS event_date, event_name,
    LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path,
    EXISTS(SELECT 1 FROM UNNEST(items) i WHERE i.quantity IS NOT NULL AND i.quantity > 0) AS q_pos
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131'
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
),
s AS (
  SELECT session_key, MIN(event_date) AS session_date,
    LOGICAL_OR(event_name = 'view_item' AND path IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')) AS view_list,
    LOGICAL_OR(event_name = 'page_view' AND path IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')) AS pv_list,
    LOGICAL_OR(event_name = 'add_to_cart') AS cart_any,
    LOGICAL_OR(event_name = 'add_to_cart' AND q_pos) AS cart_q,
    LOGICAL_OR(event_name = 'begin_checkout') AS has_checkout,
    LOGICAL_OR(event_name = 'purchase') AS has_purchase
  FROM ev GROUP BY session_key
)
SELECT session_date,
  COUNT(*) AS s0,
  COUNTIF(view_list OR cart_any OR has_checkout OR has_purchase) AS s1_view,
  COUNTIF(pv_list OR cart_any OR has_checkout OR has_purchase) AS s1_pv,
  COUNTIF(cart_any OR has_checkout OR has_purchase) AS s2,
  COUNTIF(cart_q OR has_checkout OR has_purchase) AS s2q_cum,
  COUNTIF(cart_q) AS s2q_only,
  COUNTIF(has_checkout OR has_purchase) AS s3,
  COUNTIF(has_purchase) AS s4,
  COUNTIF(cart_q) AS c_q_sessions, COUNTIF(cart_q AND has_checkout) AS c_q_checkout, COUNTIF(cart_q AND has_purchase) AS c_q_purchase,
  COUNTIF(cart_any AND NOT cart_q) AS c_q0_sessions, COUNTIF(cart_any AND NOT cart_q AND has_checkout) AS c_q0_checkout, COUNTIF(cart_any AND NOT cart_q AND has_purchase) AS c_q0_purchase
FROM s GROUP BY session_date ORDER BY session_date
