-- 목적: 데이터 품질 점검 ④ - 36번 코호트를 "정제된 구매" 기준으로 다시 계산해 기존 수치와 비교한다.
-- 정제 기준: revenue > 0인 purchase만 유효 구매로 인정 (revenue=0은 전부 transaction_id=NULL이며 실제 매출이 없음).
-- (거래 중복은 유저 단위 이진 지표(구매했는가)에는 영향이 없으므로 여기서는 revenue>0 필터만 다르다.)
-- cart→checkout은 purchase와 무관하므로 36번과 동일해야 한다(검증용으로 같이 출력).

WITH events AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    event_name,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
first_cart AS (
  SELECT user_pseudo_id, MIN(event_date) AS first_cart_date
  FROM events
  WHERE event_name = 'add_to_cart'
  GROUP BY user_pseudo_id
),
user_outcome AS (
  SELECT
    fc.user_pseudo_id,
    fc.first_cart_date,
    MAX(CASE WHEN e.event_name = 'begin_checkout' AND e.event_date >= fc.first_cart_date THEN 1 ELSE 0 END) AS did_checkout,
    MAX(CASE WHEN e.event_name = 'purchase' AND e.event_date >= fc.first_cart_date THEN 1 ELSE 0 END) AS did_purchase_raw,
    MAX(CASE WHEN e.event_name = 'purchase' AND e.revenue > 0 AND e.event_date >= fc.first_cart_date THEN 1 ELSE 0 END) AS did_purchase_valid
  FROM first_cart fc
  LEFT JOIN events e ON e.user_pseudo_id = fc.user_pseudo_id
  GROUP BY fc.user_pseudo_id, fc.first_cart_date
)
SELECT
  DATE_TRUNC(first_cart_date, WEEK(MONDAY)) AS cohort_week,
  COUNT(*) AS users_added_to_cart,
  SUM(did_checkout) AS users_began_checkout,
  SUM(did_purchase_raw) AS users_purchased_raw,
  SUM(did_purchase_valid) AS users_purchased_valid
FROM user_outcome
GROUP BY cohort_week
ORDER BY cohort_week
