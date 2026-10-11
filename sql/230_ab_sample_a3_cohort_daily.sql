-- 목적: A/B 표본 크기 계산용(A3) - sql/216과 같은 코호트(기간 안 유저의 첫 "목록 경로 page_view가 있고 add_to_cart는 없는 세션")를 진입일별로 집계.
-- 결과 = 진입 세션 시작 이후 7일 안 이후 세션 중 add_to_cart가 있는가(cart7), 이후 세션이 있는가(return7). 기간: B 12/1~12/13, D 12/19~1/11, R 1/12~1/24.
WITH ev AS (
  SELECT user_pseudo_id,
    CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    PARSE_DATE('%Y%m%d', event_date) AS event_date, event_timestamp, event_name,
    LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131'
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
),
s AS (
  SELECT user_pseudo_id, session_key, MIN(event_timestamp) AS start_ts, MIN(event_date) AS session_date,
    LOGICAL_OR(event_name = 'page_view' AND path IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')) AS pv_list,
    LOGICAL_OR(event_name = 'page_view' AND path = '/google+redesign/apparel/hats') AS hats_pv,
    LOGICAL_OR(event_name = 'add_to_cart') AS has_cart
  FROM ev GROUP BY user_pseudo_id, session_key
),
cohort AS (
  SELECT *, CASE WHEN session_date BETWEEN '2020-12-01' AND '2020-12-13' THEN 'B'
                 WHEN session_date BETWEEN '2020-12-19' AND '2021-01-11' THEN 'D'
                 WHEN session_date BETWEEN '2021-01-12' AND '2021-01-24' THEN 'R' END AS period
  FROM s WHERE pv_list AND NOT has_cart
  QUALIFY period IS NOT NULL AND ROW_NUMBER() OVER (PARTITION BY user_pseudo_id, period ORDER BY start_ts) = 1
)
SELECT c.period, c.session_date AS d, COUNT(*) AS users,
  COUNTIF(EXISTS(SELECT 1 FROM s x WHERE x.user_pseudo_id = c.user_pseudo_id AND x.start_ts > c.start_ts AND x.start_ts <= c.start_ts + 7*24*3600*1000000)) AS return7,
  COUNTIF(EXISTS(SELECT 1 FROM s x WHERE x.user_pseudo_id = c.user_pseudo_id AND x.start_ts > c.start_ts AND x.start_ts <= c.start_ts + 7*24*3600*1000000 AND x.has_cart)) AS cart7
FROM cohort c GROUP BY c.period, c.session_date ORDER BY c.period, c.session_date
