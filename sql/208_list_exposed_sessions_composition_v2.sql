-- (docs/09 정정판) s1 = 목록 경로 view_item 또는 이후 단계 이벤트가 있는 세션 (sql/207과 동일). 초판(sql/194 원본)은 모든 view_item을 s1로 셌음.
-- 목적: 목록 노출 도달(s1) 세션의 구성(신규 여부, 채널, 랜딩 페이지)이 1월 말에 바뀌었는지, 그룹별 노출->담기(s2/s1) 비율 확인.
-- 주(월요일 시작) 단위. 세션 키/날짜 정의는 sql/191과 동일. 랜딩 = 세션의 첫 page_view 경로(쿼리스트링 제거).
WITH ev AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    event_name, event_timestamp,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
    REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)') AS path,
    device.category AS device_category,
    CASE
      WHEN traffic_source.source = 'google' AND traffic_source.medium = 'organic' THEN 'google/organic'
      WHEN traffic_source.source = '(direct)' AND traffic_source.medium = '(none)' THEN 'direct'
      WHEN traffic_source.source = 'google' AND traffic_source.medium = 'cpc' THEN 'google/cpc'
      WHEN traffic_source.source = 'shop.googlemerchandisestore.com' AND traffic_source.medium = 'referral' THEN 'self-referral'
      ELSE '식별불가/기타'
    END AS channel
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131'
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
),
sessions AS (
  SELECT
    session_key,
    MIN(event_date) AS session_date,
    MAX(session_number) = 1 AS is_new,
    ANY_VALUE(channel) AS channel,
    ANY_VALUE(device_category) AS device_category,
    ARRAY_AGG(IF(event_name = 'page_view', path, NULL) IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS landing_path,
    LOGICAL_OR((event_name = 'view_item' AND LOWER(path) IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')) OR event_name IN ('add_to_cart', 'begin_checkout', 'purchase')) AS s1,
    LOGICAL_OR(event_name IN ('add_to_cart', 'begin_checkout', 'purchase')) AS s2
  FROM ev GROUP BY session_key
)
SELECT
  DATE_TRUNC(session_date, WEEK(MONDAY)) AS week_start,
  is_new, channel, device_category, landing_path,
  COUNT(*) AS s1_sessions, COUNTIF(s2) AS s2_sessions
FROM sessions WHERE s1
GROUP BY week_start, is_new, channel, device_category, landing_path
