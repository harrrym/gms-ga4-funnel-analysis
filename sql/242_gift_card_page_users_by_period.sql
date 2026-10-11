-- 목적: 기프트카드 페이지 방문 유저 수를 기간별 고유 유저로 집계(일별 합계는 중복 유저를 세므로). 기간: 11월(11/1~11/30), 기준선 12/1~12/13, 선행 12/14~12/18, 하락 12/19~1/11, 회복기 1/12~1/31. 세션 날짜 기준.
WITH ev AS (
  SELECT user_pseudo_id, (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sid,
    PARSE_DATE('%Y%m%d', event_date) AS d, event_name,
    LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
s AS (
  SELECT user_pseudo_id, sid, MIN(d) AS sd,
    LOGICAL_OR(event_name = 'page_view' AND path IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')) AS pv_list,
    LOGICAL_OR(event_name = 'page_view' AND REGEXP_CONTAINS(IFNULL(path, ''), r'gift[ +]?cards?')) AS pv_gift
  FROM ev WHERE sid IS NOT NULL GROUP BY user_pseudo_id, sid
)
SELECT CASE WHEN sd <= '2020-11-30' THEN '0 11월' WHEN sd <= '2020-12-13' THEN '1 기준선' WHEN sd <= '2020-12-18' THEN '2 선행'
            WHEN sd <= '2021-01-11' THEN '3 하락' ELSE '4 회복기' END AS period,
  COUNT(DISTINCT user_pseudo_id) AS users, COUNT(DISTINCT IF(pv_list, user_pseudo_id, NULL)) AS list_users,
  COUNT(DISTINCT IF(pv_gift, user_pseudo_id, NULL)) AS gift_users,
  COUNT(*) AS sessions, COUNTIF(pv_list) AS list_sessions, COUNTIF(pv_gift) AS gift_sessions
FROM s GROUP BY period ORDER BY period
