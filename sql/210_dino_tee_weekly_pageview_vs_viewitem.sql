-- 목적: Google Dino Game Tee 상품 페이지의 주별 page_view 세션 수 vs 그 페이지에서 view_item이 찍힌 세션 수 (12/1~1/31).
-- 1월 말 "상세 경로 view_item 세션 증가"가 방문 증가인지 view_item 기록 시작인지 구분.
WITH ev AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    PARSE_DATE('%Y%m%d', event_date) AS event_date, event_name,
    LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131'
    AND event_name IN ('page_view', 'view_item', 'add_to_cart')
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
)
SELECT DATE_TRUNC(event_date, WEEK(MONDAY)) AS week_start,
  COUNT(DISTINCT IF(event_name = 'page_view', session_key, NULL)) AS pageview_sessions,
  COUNT(DISTINCT IF(event_name = 'view_item', session_key, NULL)) AS viewitem_sessions,
  COUNT(DISTINCT IF(event_name = 'add_to_cart', session_key, NULL)) AS cart_sessions
FROM ev WHERE path LIKE '%google+dino+game+tee' GROUP BY week_start ORDER BY week_start
