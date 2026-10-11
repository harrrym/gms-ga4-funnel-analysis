-- 목적: OMTM(구매전환율 = 구매 세션 / 전체 세션, docs/02·sql/01과 같은 세션 단위 LOGICAL_OR 방식)을
-- 12월 초(12/1~12/13) vs 하락구간(12/14~1/11)으로 계산하고, 방문->담기->결제시작->구매 세션 단계별 수를 함께 반환.
-- 세션 키/ga_session_id NULL 제외 규칙은 sql/01과 동일. 주 대신 기간으로 집계.
WITH session_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210111'
),
sessions AS (
  SELECT
    CASE WHEN event_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '12월 초' END AS period,
    CONCAT(user_pseudo_id, '-', CAST(session_id AS STRING)) AS session_key,
    LOGICAL_OR(event_name = 'add_to_cart') AS has_cart,
    LOGICAL_OR(event_name = 'begin_checkout') AS has_checkout,
    LOGICAL_OR(event_name = 'purchase') AS has_purchase
  FROM session_events
  WHERE session_id IS NOT NULL
    AND event_date BETWEEN '2020-12-01' AND '2021-01-11'
  GROUP BY period, session_key
)
SELECT
  period,
  COUNT(*) AS sessions,
  COUNTIF(has_cart) AS cart_sessions,
  COUNTIF(has_checkout) AS checkout_sessions,
  COUNTIF(has_purchase) AS purchase_sessions,
  COUNTIF(has_cart AND has_checkout) AS cart_and_checkout,
  COUNTIF(has_cart AND has_purchase) AS cart_and_purchase,
  COUNTIF(has_checkout AND has_purchase) AS checkout_and_purchase,
  COUNTIF(has_purchase AND NOT has_checkout) AS purchase_without_checkout,
  COUNTIF(has_checkout AND NOT has_cart) AS checkout_without_cart,
  COUNTIF(has_purchase AND NOT has_cart) AS purchase_without_cart
FROM sessions
GROUP BY period
ORDER BY period
