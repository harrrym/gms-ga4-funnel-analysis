-- 목적: 가설 A(구성 효과) 검증 - cart→checkout 하락이 "신규 방문자 비중 증가"로 설명되는지,
-- 아니면 신규/재방문 각 그룹 안에서도 실제로 전환율이 떨어졌는지 구분한다.
-- 36번과 동일한 유저 단위 코호트 방법론에, "첫 add_to_cart가 일어난 세션이 그 유저의 첫 세션(session_number=1)이었는지"로
-- 신규/재방문을 나눈다.

WITH first_cart_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_cart_date,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS cart_session_number
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp ASC) = 1
),
events AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
user_outcome AS (
  SELECT
    fc.user_pseudo_id,
    fc.first_cart_date,
    CASE WHEN fc.cart_session_number = 1 THEN '신규(첫 세션에 담음)' ELSE '재방문(이전 방문 있음)' END AS visitor_type,
    MAX(CASE WHEN e.event_name = 'begin_checkout' AND e.event_date >= fc.first_cart_date THEN 1 ELSE 0 END) AS did_checkout
  FROM first_cart_event fc
  LEFT JOIN events e ON e.user_pseudo_id = fc.user_pseudo_id
  WHERE fc.cart_session_number IS NOT NULL
  GROUP BY fc.user_pseudo_id, fc.first_cart_date, visitor_type
)
SELECT
  DATE_TRUNC(first_cart_date, WEEK(MONDAY)) AS cohort_week,
  visitor_type,
  COUNT(*) AS users,
  SUM(did_checkout) AS checkout_users,
  ROUND(SAFE_DIVIDE(SUM(did_checkout), COUNT(*)) * 100, 2) AS cart_to_checkout_rate
FROM user_outcome
GROUP BY cohort_week, visitor_type
ORDER BY cohort_week, visitor_type
