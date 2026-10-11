-- 목적: docs/04 "임팩트 추정"(매출손실 역산)에 쓸 cart->purchase 전환율을 새 평상시 정의로 재계산.
-- 36번과 동일 방법론(첫 add_to_cart 유저 코호트), outcome=purchase, period는 4-way.

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
      WHEN first_cart_date BETWEEN '2020-11-23' AND '2020-11-30' THEN '블프구간'
      WHEN first_cart_date < '2020-12-14' THEN '평상시'
      ELSE '사후구간'
    END AS period
  FROM user_outcome
)
SELECT
  period,
  COUNT(*) AS users,
  SUM(did_purchase) AS purchased_users,
  ROUND(SAFE_DIVIDE(SUM(did_purchase), COUNT(*)) * 100, 2) AS cart_to_purchase_rate
FROM labeled
GROUP BY period
ORDER BY period
