-- 목적: A/B 2단계(배송 마감 이후 이탈자, 바로 vs 1월 중순) 표본 크기 계산용 - sql/216과 같은 코호트(기간 안 유저의 첫 "목록 경로 page_view가 있고 add_to_cart는 없는 세션") 중
-- 하락구간(12/19~1/11) 이탈자를 진입일별로 집계. 결과 = 진입 세션 이후 1/31까지 이후 세션 중 add_to_cart가 있는가(cart_by_0131), 이후 세션이 있는가(return_by_0131).
-- 광고를 보여주지 않은 2020년의 자연 값이다. 진입 세션 시작 이후에 시작한 세션만 센다.
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
SELECT c.session_date AS d, COUNT(*) AS users,
  COUNTIF(EXISTS(SELECT 1 FROM s x WHERE x.user_pseudo_id = c.user_pseudo_id AND x.start_ts > c.start_ts)) AS return_by_0131,
  COUNTIF(EXISTS(SELECT 1 FROM s x WHERE x.user_pseudo_id = c.user_pseudo_id AND x.start_ts > c.start_ts AND x.has_cart)) AS cart_by_0131
FROM cohort c WHERE c.period = 'D' GROUP BY c.session_date ORDER BY c.session_date
