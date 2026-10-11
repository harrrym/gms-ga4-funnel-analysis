-- 목적: A/B 표본 크기 계산용(B1) - 품절 추정 상품이 목록에 노출된 유저의 첫 노출 후 7일 안 구매율, 진입일별.
-- 품절 추정(docs/10 H2): 마지막 구매일 이전 28일 구매 10개 이상, 마지막 구매 1/17 이전인 37개 상품, 마지막 구매일 + 7일부터 품절로 간주. 상품명(소문자)으로 연결.
-- 노출 = 목록 경로 view_item(아이템 6개 이상)에 그 시점 품절 추정 상품이 포함됨. any = 모든 목록, hats = Hats 목록(/google+redesign/apparel/hats)만.
-- 진입 = 기간 안 유저의 첫 노출. 결과 = 진입 시각 이후 7일 안 purchase 이벤트가 있는가. 기간: B 12/1~12/13, D 12/19~1/11, R 1/12~1/24.
WITH stock AS (
  SELECT * FROM UNNEST([
    STRUCT('#iamremarkable ladies t-shirt' AS name, DATE '2020-12-28' AS start_d),
    STRUCT('#iamremarkable lapel pin' AS name, DATE '2021-01-05' AS start_d),
    STRUCT('android hipster pin' AS name, DATE '2021-01-17' AS start_d),
    STRUCT('android iconic backpack' AS name, DATE '2020-12-31' AS start_d),
    STRUCT('android iconic mug gray' AS name, DATE '2020-12-22' AS start_d),
    STRUCT('android iconic notebook' AS name, DATE '2021-01-13' AS start_d),
    STRUCT('gift card - $25.00' AS name, DATE '2021-01-06' AS start_d),
    STRUCT('google 16 oz tumbler blue' AS name, DATE '2020-12-21' AS start_d),
    STRUCT('google blue yoyo' AS name, DATE '2020-12-22' AS start_d),
    STRUCT('google bot' AS name, DATE '2020-12-21' AS start_d),
    STRUCT('google clear pen 4-pack' AS name, DATE '2020-12-23' AS start_d),
    STRUCT('google cloth & pouch black' AS name, DATE '2020-12-15' AS start_d),
    STRUCT('google decal' AS name, DATE '2020-12-18' AS start_d),
    STRUCT('google felt refillable journal' AS name, DATE '2021-01-18' AS start_d),
    STRUCT('google infant hero onesie grey' AS name, DATE '2020-12-24' AS start_d),
    STRUCT('google infant hero tee olive' AS name, DATE '2021-01-11' AS start_d),
    STRUCT('google jotter task pad' AS name, DATE '2021-01-20' AS start_d),
    STRUCT('google leather strap hat black' AS name, DATE '2020-12-01' AS start_d),
    STRUCT('google leather strap hat blue' AS name, DATE '2020-12-16' AS start_d),
    STRUCT('google mural socks' AS name, DATE '2020-12-24' AS start_d),
    STRUCT('google nyc campus mug' AS name, DATE '2021-01-12' AS start_d),
    STRUCT('google premium sunglasses' AS name, DATE '2020-12-29' AS start_d),
    STRUCT('google red kids sunglasses' AS name, DATE '2020-12-22' AS start_d),
    STRUCT('google red yoyo' AS name, DATE '2020-12-29' AS start_d),
    STRUCT('google sf campus lapel pin' AS name, DATE '2020-12-23' AS start_d),
    STRUCT('google sunnyvale campus bottle' AS name, DATE '2020-12-22' AS start_d),
    STRUCT('google sunnyvale campus mug' AS name, DATE '2020-12-19' AS start_d),
    STRUCT('google super g tumbler (blue lid)' AS name, DATE '2020-12-11' AS start_d),
    STRUCT('google toddler hero tee black' AS name, DATE '2020-12-25' AS start_d),
    STRUCT('google utensil set' AS name, DATE '2021-01-08' AS start_d),
    STRUCT('maze pen' AS name, DATE '2020-12-30' AS start_d),
    STRUCT('mural food container' AS name, DATE '2020-12-24' AS start_d),
    STRUCT('white google shoreline bottle' AS name, DATE '2021-01-19' AS start_d),
    STRUCT('youtube crew socks' AS name, DATE '2020-12-21' AS start_d),
    STRUCT('youtube jotter task pad' AS name, DATE '2021-01-06' AS start_d),
    STRUCT('youtube play mug' AS name, DATE '2020-12-25' AS start_d),
    STRUCT('youtube transmission journal red' AS name, DATE '2020-12-20' AS start_d)
  ])
),
ev AS (
  SELECT user_pseudo_id, (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sid, PARSE_DATE('%Y%m%d', event_date) AS d, event_timestamp AS ts, event_name, items,
    LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131'
),
expo AS (
  SELECT e.user_pseudo_id, e.ts, e.d, e.path = '/google+redesign/apparel/hats' AS is_hats
  FROM ev e
  WHERE e.sid IS NOT NULL AND e.event_name = 'view_item' AND ARRAY_LENGTH(e.items) >= 6
    AND e.path IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')
    AND EXISTS(SELECT 1 FROM UNNEST(e.items) it JOIN stock s ON LOWER(TRIM(it.item_name)) = s.name WHERE e.d >= s.start_d)
),
pur AS (SELECT user_pseudo_id, ts FROM ev WHERE event_name = 'purchase' AND sid IS NOT NULL),
ent AS (
  SELECT 'any' AS def, user_pseudo_id, MIN(ts) AS entry_ts, ARRAY_AGG(d ORDER BY ts LIMIT 1)[OFFSET(0)] AS entry_d FROM expo
  WHERE (d BETWEEN '2020-12-01' AND '2020-12-13' OR d BETWEEN '2020-12-19' AND '2021-01-11' OR d BETWEEN '2021-01-12' AND '2021-01-24')
  GROUP BY user_pseudo_id, CASE WHEN d <= '2020-12-13' THEN 'B' WHEN d <= '2021-01-11' THEN 'D' ELSE 'R' END
  UNION ALL
  SELECT 'hats', user_pseudo_id, MIN(ts), ARRAY_AGG(d ORDER BY ts LIMIT 1)[OFFSET(0)] FROM expo
  WHERE is_hats AND (d BETWEEN '2020-12-01' AND '2020-12-13' OR d BETWEEN '2020-12-19' AND '2021-01-11' OR d BETWEEN '2021-01-12' AND '2021-01-24')
  GROUP BY user_pseudo_id, CASE WHEN d <= '2020-12-13' THEN 'B' WHEN d <= '2021-01-11' THEN 'D' ELSE 'R' END
)
SELECT def, CASE WHEN entry_d <= '2020-12-13' THEN 'B' WHEN entry_d <= '2021-01-11' THEN 'D' ELSE 'R' END AS period, entry_d AS d,
  COUNT(*) AS users,
  COUNTIF(EXISTS(SELECT 1 FROM pur p WHERE p.user_pseudo_id = a.user_pseudo_id AND p.ts >= a.entry_ts AND p.ts <= a.entry_ts + 7*24*3600*1000000)) AS buyers7
FROM ent a GROUP BY def, period, entry_d ORDER BY def, period, entry_d
