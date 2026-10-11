-- 목적: A/B 표본 크기 계산용(B2) - 목록 도달 유저의 (1) 첫 도달 후 7일 안 담기율(유저 단위), (2) 세션 단위 ②와 유저 안 상관 추정용 (목록 도달 세션 수, 담기 도달 세션 수) 분포.
-- 목록 도달 세션 = 목록 경로 page_view가 있거나 이후 단계(add_to_cart, begin_checkout, purchase)가 있는 세션, 담기 도달 세션 = add_to_cart·begin_checkout·purchase 중 하나가 있는 세션(docs/09 누적 정의, page_view 기준 ①).
-- 진입 = 기간 안 유저의 첫 목록 도달 세션 시작, cart7 = 진입 시각 이후 7일 안 add_to_cart 이벤트가 있는가. 기간: B 12/1~12/13, R 1/12~1/24.
WITH ev AS (
  SELECT user_pseudo_id, (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sid, PARSE_DATE('%Y%m%d', event_date) AS d, event_timestamp AS ts, event_name,
    LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131'
),
ev2 AS (SELECT *, CONCAT(user_pseudo_id, '-', CAST(sid AS STRING)) AS session_key FROM ev WHERE sid IS NOT NULL),
sess AS (
  SELECT user_pseudo_id, session_key, MIN(ts) AS start_ts, MIN(d) AS sd,
    LOGICAL_OR(event_name = 'page_view' AND path IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')) AS pv_list,
    LOGICAL_OR(event_name IN ('add_to_cart', 'begin_checkout', 'purchase')) AS cart_reached
  FROM ev2 GROUP BY user_pseudo_id, session_key
),
ls AS (
  SELECT *, CASE WHEN sd BETWEEN '2020-12-01' AND '2020-12-13' THEN 'B' WHEN sd BETWEEN '2021-01-12' AND '2021-01-24' THEN 'R' END AS period
  FROM sess WHERE pv_list OR cart_reached
),
carts AS (SELECT user_pseudo_id, ts FROM ev2 WHERE event_name = 'add_to_cart'),
u AS (
  SELECT period, user_pseudo_id, MIN(start_ts) AS entry_ts, ARRAY_AGG(sd ORDER BY start_ts LIMIT 1)[OFFSET(0)] AS entry_d,
    COUNT(*) AS n_list, COUNTIF(cart_reached) AS n_cart
  FROM ls WHERE period IS NOT NULL GROUP BY period, user_pseudo_id
)
SELECT period, entry_d AS d, n_list, n_cart, COUNT(*) AS users,
  COUNTIF(EXISTS(SELECT 1 FROM carts c WHERE c.user_pseudo_id = u.user_pseudo_id AND c.ts >= u.entry_ts AND c.ts <= u.entry_ts + 7*24*3600*1000000)) AS cart7_users
FROM u GROUP BY period, d, n_list, n_cart ORDER BY period, d, n_list, n_cart
