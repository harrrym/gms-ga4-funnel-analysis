-- 목적: 기프트카드 페이지(경로에 gift card/gift+cards 포함, 상세 .axd 포함) 방문과 목록 경로 방문의 일별 규모, 기프트카드 주문 수. 11/1~1/31.
-- 세션 날짜 = 세션 첫 이벤트 날짜. list = 목록 경로 page_view(sql/216과 같은 32개 경로, 기프트카드 목록 경로 포함), all = 세션 전체.
WITH ev AS (
  SELECT user_pseudo_id, (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sid, PARSE_DATE('%Y%m%d', event_date) AS d, event_timestamp AS ts, event_name, LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
s AS (
  SELECT user_pseudo_id, CONCAT(user_pseudo_id, '-', CAST(sid AS STRING)) AS session_key, MIN(d) AS sd,
    LOGICAL_OR(event_name = 'page_view' AND path IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')) AS pv_list,
    LOGICAL_OR(event_name = 'page_view' AND REGEXP_CONTAINS(IFNULL(path, ''), r'gift[ +]?cards?')) AS pv_gift,
    LOGICAL_OR(event_name = 'page_view' AND REGEXP_CONTAINS(IFNULL(path, ''), r'gift[ +]?cards?/')) AS pv_gift_detail
  FROM ev WHERE sid IS NOT NULL GROUP BY user_pseudo_id, session_key
),
o AS (
  SELECT PARSE_DATE('%Y%m%d', event_date) AS d, COUNT(DISTINCT ecommerce.transaction_id) AS gift_orders
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) i
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131' AND event_name = 'purchase' AND LOWER(i.item_name) LIKE '%gift card%'
  GROUP BY d
)
SELECT s.sd AS d, COUNT(*) AS sessions, COUNT(DISTINCT s.user_pseudo_id) AS users,
  COUNTIF(pv_list) AS list_sessions, COUNT(DISTINCT IF(pv_list, s.user_pseudo_id, NULL)) AS list_users,
  COUNTIF(pv_gift) AS gift_sessions, COUNT(DISTINCT IF(pv_gift, s.user_pseudo_id, NULL)) AS gift_users,
  COUNTIF(pv_gift_detail) AS gift_detail_sessions,
  ANY_VALUE(IFNULL(o.gift_orders, 0)) AS gift_orders
FROM s LEFT JOIN o ON o.d = s.sd
GROUP BY s.sd ORDER BY s.sd
