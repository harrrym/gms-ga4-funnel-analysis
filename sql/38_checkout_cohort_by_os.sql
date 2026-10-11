-- 목적: 37번에서 device_category(desktop/mobile/tablet)로는 하락폭이 균일했는데,
-- mobile 안에서 iOS와 Android가 실제로는 다르게 움직였을 가능성을 확인한다
-- (예: 애플페이/특정 브라우저 결제 이슈처럼 OS 단위 이슈는 device_category 레벨에서는 안 보일 수 있음).
-- 36번과 동일한 유저 단위/세션 무관 방법론, 첫 add_to_cart 이벤트 행의 operating_system을 붙인다.

WITH first_cart_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_cart_date,
    device.category AS device_category,
    device.operating_system AS operating_system
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
    fc.device_category,
    fc.operating_system,
    MAX(CASE WHEN e.event_name = 'begin_checkout' AND e.event_date >= fc.first_cart_date THEN 1 ELSE 0 END) AS did_checkout
  FROM first_cart_event fc
  LEFT JOIN events e ON e.user_pseudo_id = fc.user_pseudo_id
  GROUP BY fc.user_pseudo_id, fc.first_cart_date, fc.device_category, fc.operating_system
),
labeled AS (
  SELECT
    *,
    CASE WHEN first_cart_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '평상시' END AS period
  FROM user_outcome
  WHERE device_category = 'mobile'
)
SELECT
  operating_system,
  period,
  COUNT(*) AS users,
  SUM(did_checkout) AS checkout_users,
  ROUND(SAFE_DIVIDE(SUM(did_checkout), COUNT(*)) * 100, 2) AS cart_to_checkout_rate
FROM labeled
GROUP BY operating_system, period
ORDER BY operating_system, period
