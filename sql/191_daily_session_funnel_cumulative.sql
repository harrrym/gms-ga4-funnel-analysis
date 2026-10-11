-- 목적: OMTM(구매 세션/전체 세션)과 단계별 도달 세션을 11/1~1/31 일별로 계산 (docs/09 분석 1·2단계).
-- 단계 정의(누적, "그 단계 또는 이후 단계 이벤트가 있는 세션"): 각 단계 비율 <= 100%이고 곱하면 OMTM과 정확히 일치.
--   s0 전체 세션 / s1 목록 노출 도달(view_item|add_to_cart|begin_checkout|purchase) / s2 담기 도달(add_to_cart|begin_checkout|purchase)
--   s3 결제시작 도달(begin_checkout|purchase) / s4 구매(purchase)
-- 세션 날짜 = 세션의 첫 이벤트 날짜. 세션 키 = user_pseudo_id + ga_session_id (ga_session_id NULL 제외, sql/01과 동일).
WITH ev AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
),
sessions AS (
  SELECT
    session_key,
    MIN(event_date) AS session_date,
    LOGICAL_OR(event_name = 'view_item') AS has_view,
    LOGICAL_OR(event_name = 'add_to_cart') AS has_cart,
    LOGICAL_OR(event_name = 'begin_checkout') AS has_checkout,
    LOGICAL_OR(event_name = 'purchase') AS has_purchase
  FROM ev GROUP BY session_key
)
SELECT
  session_date,
  COUNT(*) AS s0_sessions,
  COUNTIF(has_view OR has_cart OR has_checkout OR has_purchase) AS s1_list_exposed,
  COUNTIF(has_cart OR has_checkout OR has_purchase) AS s2_cart_reached,
  COUNTIF(has_checkout OR has_purchase) AS s3_checkout_reached,
  COUNTIF(has_purchase) AS s4_purchase
FROM sessions
GROUP BY session_date
ORDER BY session_date
