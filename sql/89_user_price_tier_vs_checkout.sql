-- 목적: 3단계 - 유저별 카트 가격대와 cart→checkout 전환 여부를 직접 연결.
-- If-Then 가설: "가격이 오른 정도가 클수록 결제시작 전환율이 더 크게 떨어져야 한다"
-- 36번과 동일한 유저 단위 코호트 방법론. 유저의 카트 가격 = 첫 add_to_cart 이벤트 안 아이템들의
-- 수량(quantity) 가중평균 단가. 가격 구간(4분위)은 두 기간을 합친 전체 분포 기준으로 나눠서
-- 평상시/하락구간 사이에 같은 구간을 공정하게 비교할 수 있게 한다.

WITH first_cart_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_cart_date,
    items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp ASC) = 1
),
user_price AS (
  SELECT
    user_pseudo_id,
    first_cart_date,
    SAFE_DIVIDE(
      SUM(item.price * IFNULL(item.quantity, 1)),
      SUM(IFNULL(item.quantity, 1))
    ) AS cart_weighted_avg_price
  FROM first_cart_event, UNNEST(items) AS item
  WHERE item.price IS NOT NULL
  GROUP BY user_pseudo_id, first_cart_date
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
    up.user_pseudo_id,
    up.first_cart_date,
    up.cart_weighted_avg_price,
    MAX(CASE WHEN e.event_name = 'begin_checkout' AND e.event_date >= up.first_cart_date THEN 1 ELSE 0 END) AS did_checkout
  FROM user_price up
  LEFT JOIN events e ON e.user_pseudo_id = up.user_pseudo_id
  GROUP BY up.user_pseudo_id, up.first_cart_date, up.cart_weighted_avg_price
),
labeled AS (
  SELECT
    *,
    CASE WHEN first_cart_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '평상시' END AS period,
    NTILE(4) OVER (ORDER BY cart_weighted_avg_price) AS price_tier
  FROM user_outcome
)
SELECT
  price_tier,
  period,
  COUNT(*) AS users,
  ROUND(MIN(cart_weighted_avg_price), 2) AS min_price,
  ROUND(MAX(cart_weighted_avg_price), 2) AS max_price,
  SUM(did_checkout) AS checkout_users,
  ROUND(SAFE_DIVIDE(SUM(did_checkout), COUNT(*)) * 100, 2) AS cart_to_checkout_rate
FROM labeled
GROUP BY price_tier, period
ORDER BY price_tier, period
