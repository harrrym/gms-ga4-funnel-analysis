-- 목적: 일별 ②(목록 노출 도달 세션 중 담기 도달 세션)를 기기·브라우저별로 (12/1~1/31). 단계 정의는 sql/191과 동일(누적).
WITH ev AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    PARSE_DATE('%Y%m%d', event_date) AS event_date, event_name,
    device.category AS device_category, device.web_info.browser AS browser
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131'
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
),
s AS (
  SELECT session_key, MIN(event_date) AS session_date, ANY_VALUE(device_category) AS device_category, ANY_VALUE(browser) AS browser,
    LOGICAL_OR(event_name IN ('view_item', 'add_to_cart', 'begin_checkout', 'purchase')) AS s1,
    LOGICAL_OR(event_name IN ('add_to_cart', 'begin_checkout', 'purchase')) AS s2
  FROM ev GROUP BY session_key
)
SELECT session_date, device_category, browser, COUNTIF(s1) AS s1_sessions, COUNTIF(s2) AS s2_sessions
FROM s GROUP BY session_date, device_category, browser
