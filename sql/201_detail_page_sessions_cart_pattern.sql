-- 목적: 상품 상세 후보 페이지(page_view, /google+redesign/ 아래 목록이 아닌 경로)를 본 세션의 담기 양상 확인 (12/1~1/11).
-- 목록 경로 집합 = sql/188에서 add_to_cart가 10건 이상 찍힌 경로 + store/asearch. 대소문자 무시.
-- (초판은 view_item 30건 이상 기준이라 view_item이 찍히는 인기 상품 상세 URL이 목록으로 잘못 분류됨 -> 수정)
WITH ev AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    event_timestamp AS ts, event_name,
    LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210111'
    AND event_name IN ('page_view', 'view_item', 'add_to_cart', 'begin_checkout', 'purchase')
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
),
flag AS (
  SELECT *,
    (event_name = 'page_view' AND path LIKE '/google+redesign/%' AND path NOT IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')) AS is_detail,
    (path IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')) AS is_list_path
  FROM ev
),
s AS (
  SELECT session_key,
    LOGICAL_OR(is_detail) AS has_detail,
    MIN(IF(is_detail, ts, NULL)) AS first_detail_ts,
    LOGICAL_OR(event_name = 'view_item') AS has_view,
    LOGICAL_OR(event_name = 'add_to_cart') AS has_cart,
    MIN(IF(event_name = 'add_to_cart', ts, NULL)) AS first_cart_ts,
    LOGICAL_OR(event_name = 'purchase') AS has_purchase,
    -- 상세 후보 첫 조회 이후에 발생한 add_to_cart가 목록 경로에서였는지 / 상세 경로에서였는지
    COUNTIF(event_name = 'add_to_cart' AND is_list_path) AS cart_on_list,
    COUNTIF(event_name = 'add_to_cart' AND NOT is_list_path) AS cart_not_list
  FROM flag GROUP BY session_key
),
t AS (
  SELECT s.*,
    (SELECT COUNTIF(f.event_name = 'add_to_cart') FROM flag f WHERE f.session_key = s.session_key AND f.ts > s.first_detail_ts) AS cart_after_detail,
    (SELECT COUNTIF(f.event_name = 'add_to_cart' AND f.is_list_path) FROM flag f WHERE f.session_key = s.session_key AND f.ts > s.first_detail_ts) AS cart_after_detail_on_list
  FROM s
)
SELECT
  has_detail,
  COUNT(*) AS sessions,
  COUNTIF(has_view) AS sessions_with_view_item,
  COUNTIF(has_cart) AS sessions_with_cart,
  COUNTIF(has_purchase) AS sessions_with_purchase,
  COUNTIF(has_cart AND cart_after_detail = 0) AS cart_only_before_detail,
  COUNTIF(has_cart AND cart_after_detail > 0) AS cart_after_detail_sessions,
  COUNTIF(cart_after_detail_on_list > 0) AS cart_after_detail_on_list_sessions,
  COUNTIF(cart_not_list > 0) AS sessions_with_cart_on_nonlist
FROM t GROUP BY has_detail ORDER BY has_detail
