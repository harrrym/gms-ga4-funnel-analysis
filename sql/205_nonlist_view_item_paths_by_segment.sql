-- 목적: 목록 경로가 아닌 곳에서 view_item이 찍힌 세션이 1/21 이후 늘어난 이유 확인 - 경로별, 구간별(12/1~12/15, 12/16~12/23, 12/24~1/20, 1/21~1/31) view_item 세션 수와 아이템 수.
WITH ev AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path,
    ARRAY_LENGTH(items) AS n_items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131' AND event_name = 'view_item'
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
)
SELECT
  CASE WHEN event_date <= '2020-12-15' THEN '1 12/1~12/15' WHEN event_date <= '2020-12-23' THEN '2 12/16~12/23'
       WHEN event_date <= '2021-01-20' THEN '3 12/24~1/20' ELSE '4 1/21~1/31' END AS seg,
  path, COUNT(DISTINCT session_key) AS sessions, COUNT(*) AS events, ROUND(AVG(n_items), 1) AS avg_items
FROM ev WHERE path NOT IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html') OR path IS NULL
GROUP BY seg, path
QUALIFY ROW_NUMBER() OVER (PARTITION BY seg ORDER BY COUNT(DISTINCT session_key) DESC) <= 12
ORDER BY seg, sessions DESC
