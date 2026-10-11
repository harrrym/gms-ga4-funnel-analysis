-- 목적: 기간 정의 통일 - "평상시"를 하락구간 이전(<12/14)이면서 블프구간(11/23~11/30) 제외로 재정의.
-- docs/04 검증1(노이즈검정)의 메인 수치(cart->checkout rate, 평상시 vs 하락구간)를 이 기준으로 재계산.
-- 36번과 동일한 유저 단위 코호트(첫 add_to_cart 기준). 1/12~1/31(사후구간)은 비교에서 제외.

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
    MAX(CASE WHEN e.event_name = 'begin_checkout' AND e.event_date >= fc.first_cart_date THEN 1 ELSE 0 END) AS did_checkout
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
  SUM(did_checkout) AS checkout_users,
  ROUND(SAFE_DIVIDE(SUM(did_checkout), COUNT(*)) * 100, 2) AS cart_to_checkout_rate
FROM labeled
GROUP BY period
ORDER BY period
