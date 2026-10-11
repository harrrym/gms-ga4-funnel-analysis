-- 목적: H1a(12월 초가 일시적으로 높았나) 검증 - 11/1~1/31 일별 OMTM·퍼널(Hats 목록 세션 구분)과 page_view 신뢰도 지표.
-- hats_pv = 세션에 Hats 목록 page_view가 있는지. s1_pv = 목록 경로 page_view 또는 이후 단계(add_to_cart|begin_checkout|purchase). s2 담기 도달, s4 구매.
-- 신뢰도: s_any_pv = page_view가 하나라도 있는 세션, pv_events = page_view 이벤트 수, pv_null_loc = page_location이 비어 있는 page_view 이벤트 수, p_with_pv_list = 목록 page_view가 있는 구매 세션.
WITH ev AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    PARSE_DATE('%Y%m%d', event_date) AS event_date, event_name,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location') AS loc,
    LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
),
s AS (
  SELECT session_key, MIN(event_date) AS session_date,
    LOGICAL_OR(event_name = 'page_view' AND path = '/google+redesign/apparel/hats') AS hats_pv,
    LOGICAL_OR(event_name = 'page_view' AND path IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')) AS pv_list,
    LOGICAL_OR(event_name = 'page_view') AS any_pv,
    COUNTIF(event_name = 'page_view') AS pv_events,
    COUNTIF(event_name = 'page_view' AND loc IS NULL) AS pv_null_loc,
    LOGICAL_OR(event_name = 'add_to_cart') AS has_cart,
    LOGICAL_OR(event_name = 'begin_checkout') AS has_checkout,
    LOGICAL_OR(event_name = 'purchase') AS has_purchase
  FROM ev GROUP BY session_key
)
SELECT session_date, hats_pv,
  COUNT(*) AS s0,
  COUNTIF(pv_list OR has_cart OR has_checkout OR has_purchase) AS s1_pv,
  COUNTIF(has_cart OR has_checkout OR has_purchase) AS s2,
  COUNTIF(has_purchase) AS s4,
  COUNTIF(any_pv) AS s_any_pv, SUM(pv_events) AS pv_events, SUM(pv_null_loc) AS pv_null_loc,
  COUNTIF(has_purchase AND pv_list) AS p_with_pv_list
FROM s GROUP BY session_date, hats_pv ORDER BY session_date, hats_pv
