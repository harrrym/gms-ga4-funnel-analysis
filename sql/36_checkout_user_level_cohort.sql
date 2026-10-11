-- 목적: 35번 쿼리에서 세션 단위 cart_to_checkout_cr이 100%를 넘는 이상현상을 발견했다.
-- 원인 추정: 장바구니가 세션을 넘어 유지되는데, 같은 세션 안에서만 add_to_cart->begin_checkout을
-- 짝지어 세다 보니 "이전 세션에 담고 이번 세션에 결제" 패턴을 놓친 것.
-- 수정: 세션이 아니라 유저 단위로, "첫 add_to_cart 시점(코호트)" 이후 "그 이후 아무 때나"
-- begin_checkout/purchase를 했는지로 다시 계산한다 (세션 경계 제거).
-- 한계: 리텐션과 동일한 censoring 문제 있음 - 관측기간(~2021-01-31) 끝에 가까운 코호트일수록
-- "아직 전환 안 한 것"과 "전환할 시간이 부족했던 것"을 구분 못 함.

WITH events AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    event_name
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
    MAX(CASE WHEN e.event_name = 'purchase' AND e.event_date >= fc.first_cart_date THEN 1 ELSE 0 END) AS did_purchase
  FROM first_cart fc
  LEFT JOIN events e ON e.user_pseudo_id = fc.user_pseudo_id
  GROUP BY fc.user_pseudo_id, fc.first_cart_date
)
SELECT
  DATE_TRUNC(first_cart_date, WEEK(MONDAY)) AS cohort_week,
  COUNT(*) AS users_added_to_cart,
  SUM(did_checkout) AS users_began_checkout,
  SUM(did_purchase) AS users_purchased,
  ROUND(SAFE_DIVIDE(SUM(did_checkout), COUNT(*)) * 100, 2) AS cart_to_checkout_rate,
  ROUND(SAFE_DIVIDE(SUM(did_purchase), SUM(did_checkout)) * 100, 2) AS checkout_to_purchase_rate,
  ROUND(SAFE_DIVIDE(SUM(did_purchase), COUNT(*)) * 100, 2) AS cart_to_purchase_rate
FROM user_outcome
GROUP BY cohort_week
ORDER BY cohort_week
