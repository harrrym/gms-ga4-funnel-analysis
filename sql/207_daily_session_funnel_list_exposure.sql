-- 목적: docs/09 퍼널 재정의. view_item은 목록 노출(목록 경로)과 상세 조회(그 외 경로, 아이템 0개)가 섞여 있어서 ①을 "목록 경로 노출"로 다시 정의.
-- s0 전체 세션 / s1 목록 노출 도달 = 목록 경로(sql/202의 경로 집합)에서 view_item이 있거나 이후 단계(add_to_cart|begin_checkout|purchase) 이벤트가 있는 세션
-- s2 담기 도달(add_to_cart|begin_checkout|purchase) / s3 결제시작 도달(begin_checkout|purchase) / s4 구매(purchase)
-- 세션 키/날짜 정의는 sql/191과 동일. 상세 경로의 view_item만 있고 이후 단계가 없는 세션은 s0에만 포함.
WITH ev AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    PARSE_DATE('%Y%m%d', event_date) AS event_date, event_name,
    LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
),
s AS (
  SELECT session_key, MIN(event_date) AS session_date,
    LOGICAL_OR(event_name = 'view_item' AND path IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')) AS view_on_list,
    LOGICAL_OR(event_name = 'add_to_cart') AS has_cart,
    LOGICAL_OR(event_name = 'begin_checkout') AS has_checkout,
    LOGICAL_OR(event_name = 'purchase') AS has_purchase
  FROM ev GROUP BY session_key
)
SELECT session_date,
  COUNT(*) AS s0_sessions,
  COUNTIF(view_on_list OR has_cart OR has_checkout OR has_purchase) AS s1_list_exposed,
  COUNTIF(has_cart OR has_checkout OR has_purchase) AS s2_cart_reached,
  COUNTIF(has_checkout OR has_purchase) AS s3_checkout_reached,
  COUNTIF(has_purchase) AS s4_purchase
FROM s GROUP BY session_date ORDER BY session_date
