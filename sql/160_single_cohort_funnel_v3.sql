-- 목적: 단일 코호트 퍼널(147번)을 평상시 정의 v3(12/1~12/13만, 11월 전체 제외)로 재계산.
-- 결제시작은 원래대로(상품 0개 포함 모든 begin_checkout).

WITH first_cart_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_cart_date
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
    MAX(CASE WHEN e.event_name = 'begin_checkout' AND e.event_date >= fc.first_cart_date THEN 1 ELSE 0 END) AS did_checkout,
    MAX(CASE WHEN e.event_name = 'purchase' AND e.event_date >= fc.first_cart_date THEN 1 ELSE 0 END) AS did_purchase
  FROM first_cart_event fc
  LEFT JOIN events e ON e.user_pseudo_id = fc.user_pseudo_id
  GROUP BY fc.user_pseudo_id, fc.first_cart_date
),
labeled AS (
  SELECT
    *,
    CASE
      WHEN first_cart_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간'
      WHEN first_cart_date BETWEEN '2020-12-01' AND '2020-12-13' THEN '평상시'
      ELSE '사후구간'
    END AS period
  FROM user_outcome
)
SELECT
  period,
  COUNT(*) AS cart_users,
  SUM(did_checkout) AS checkout_users,
  SUM(did_purchase) AS purchase_users,
  SUM(CASE WHEN did_checkout = 1 AND did_purchase = 1 THEN 1 ELSE 0 END) AS checkout_and_purchase,
  SUM(CASE WHEN did_checkout = 0 AND did_purchase = 1 THEN 1 ELSE 0 END) AS purchase_without_checkout,
  ROUND(SAFE_DIVIDE(SUM(did_checkout), COUNT(*)) * 100, 2) AS cart_to_checkout_rate,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN did_checkout = 1 AND did_purchase = 1 THEN 1 ELSE 0 END), SUM(did_checkout)) * 100, 2) AS checkout_to_purchase_rate_within_cohort,
  ROUND(SAFE_DIVIDE(SUM(did_purchase), COUNT(*)) * 100, 2) AS cart_to_purchase_rate
FROM labeled
GROUP BY period
ORDER BY period
