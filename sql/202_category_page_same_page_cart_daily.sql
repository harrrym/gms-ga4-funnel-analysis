-- 목적: 카테고리 목록 페이지별 "그 페이지에서 노출(view_item)된 세션 중 같은 페이지에서 담은 세션" (12/1~1/31, 일별).
-- 목록 경로 집합 = sql/188에서 add_to_cart가 12/1~1/11에 10건 이상 찍힌 경로(담기가 실제 일어나는 페이지) + store.html + asearch.html (소문자 비교).
-- (view_item 30건 이상 기준은 상품 상세 URL이 섞여 들어와 폐기: 상세 경로는 담기가 거의 0이라 비율이 희석됨)
-- 유형(그외형/저관여형)은 docs/07 분류(Stationery, Shop by Brand, Campus Collection=저관여, 나머지=그외)를 페이지 경로에 적용.
-- 세션 날짜 = 세션의 첫 이벤트 날짜. page 행은 (날짜,경로)별 세션 수, type 행은 (날짜,유형)별 고유 세션 수(한 세션이 여러 페이지를 볼 수 있어 중복 제거).
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
    CASE
      WHEN path = '/asearch.html' THEN '기타(스토어/검색)'
      WHEN path = '/google+redesign/apparel' THEN '그외형'
      WHEN path = '/google+redesign/apparel/hats' THEN '그외형'
      WHEN path = '/google+redesign/apparel/kids' THEN '그외형'
      WHEN path = '/google+redesign/apparel/kids/kids+infant' THEN '그외형'
      WHEN path = '/google+redesign/apparel/mens' THEN '그외형'
      WHEN path = '/google+redesign/apparel/mens/mens+t+shirts' THEN '그외형'
      WHEN path = '/google+redesign/apparel/socks' THEN '그외형'
      WHEN path = '/google+redesign/apparel/womens' THEN '그외형'
      WHEN path = '/google+redesign/bags/backpacks/' THEN '그외형'
      WHEN path = '/google+redesign/campus+collection' THEN '저관여형'
      WHEN path = '/google+redesign/clearance' THEN '그외형'
      WHEN path = '/google+redesign/drinkware/mugs+tumblers' THEN '그외형'
      WHEN path = '/google+redesign/eco+friendly' THEN '그외형'
      WHEN path = '/google+redesign/gift+cards' THEN '그외형'
      WHEN path = '/google+redesign/lifestyle' THEN '그외형'
      WHEN path = '/google+redesign/lifestyle/bags' THEN '그외형'
      WHEN path = '/google+redesign/lifestyle/drinkware' THEN '그외형'
      WHEN path = '/google+redesign/lifestyle/small+goods' THEN '그외형'
      WHEN path = '/google+redesign/new' THEN '그외형'
      WHEN path = '/google+redesign/office' THEN '저관여형'
      WHEN path = '/google+redesign/shop+by+brand' THEN '저관여형'
      WHEN path = '/google+redesign/shop+by+brand/android' THEN '저관여형'
      WHEN path = '/google+redesign/shop+by+brand/google' THEN '저관여형'
      WHEN path = '/google+redesign/shop+by+brand/google+cloud' THEN '저관여형'
      WHEN path = '/google+redesign/shop+by+brand/i+am+remarkable' THEN '저관여형'
      WHEN path = '/google+redesign/shop+by+brand/youtube' THEN '저관여형'
      WHEN path = '/google+redesign/stationery' THEN '저관여형'
      WHEN path = '/google+redesign/stationery/notebooks' THEN '저관여형'
      WHEN path = '/google+redesign/stationery/stickers' THEN '저관여형'
      WHEN path = '/google+redesign/stationery/writing' THEN '저관여형'
      WHEN path = '/store.html' THEN '기타(스토어/검색)'
      ELSE NULL END AS ptype,
    LOGICAL_OR(event_name = 'view_item') AS has_view,
    LOGICAL_OR(event_name = 'add_to_cart') AS has_cart
  FROM ev WHERE path IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html') AND event_name IN ('view_item', 'add_to_cart')
  GROUP BY session_key, path, ptype
),
spd AS (SELECT sp.*, sd.session_date FROM sp JOIN sd USING (session_key) WHERE has_view)
SELECT 'page' AS kind, session_date, path AS k, COUNT(*) AS viewed, COUNTIF(has_cart) AS carted FROM spd GROUP BY session_date, path
UNION ALL
SELECT 'type', session_date, ptype, COUNT(DISTINCT session_key), COUNT(DISTINCT IF(has_cart, session_key, NULL)) FROM spd GROUP BY session_date, ptype
ORDER BY kind, session_date, k
