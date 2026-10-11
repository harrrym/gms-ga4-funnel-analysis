-- 목적: 목록 경로별 ②를 page_view 기준으로 (docs/10 H4b 후속). (날짜, 경로)별 "그 경로의 page_view가 있는 세션 수"와 "같은 경로에서 add_to_cart도 한 세션 수". 12/1~1/31.
WITH ev AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    PARSE_DATE('%Y%m%d', event_date) AS event_date, event_name,
    LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131'
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
),
sd AS (SELECT session_key, MIN(event_date) AS session_date FROM ev GROUP BY session_key),
sp AS (
  SELECT session_key, path,
    LOGICAL_OR(event_name = 'page_view') AS has_pv,
    LOGICAL_OR(event_name = 'add_to_cart') AS has_cart
  FROM ev WHERE path IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html') AND event_name IN ('page_view', 'add_to_cart') GROUP BY session_key, path
)
SELECT sd.session_date, sp.path, COUNTIF(has_pv) AS viewed, COUNTIF(has_pv AND has_cart) AS carted
FROM sp JOIN sd USING (session_key) GROUP BY sd.session_date, sp.path
