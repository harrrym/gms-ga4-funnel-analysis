-- 목적: 36번에서 확인한 cart_to_checkout 하락(12/14~1/11)이 전체적으로 고르게 퍼진 건지,
-- 특정 세그먼트(디바이스/채널)에 몰려있는지 확인한다.
-- 36번과 동일한 유저 단위/세션 무관 방법론을 쓰되, 첫 add_to_cart 이벤트 행의 device/traffic_source를
-- QUALIFY ROW_NUMBER로 정확히 특정해서 device_category와 channel을 함께 붙인다.
-- 문제구간(12/28~1/4)만이 아니라 하락이 시작된 12/14부터 회복 전인 1/11까지를 "하락구간"으로 넓게 잡고
-- "평상시"(그 외 기간)와 비교한다.

WITH first_cart_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_cart_date,
    device.category AS device_category,
    CASE
      WHEN traffic_source.source = 'google' AND traffic_source.medium = 'organic' THEN 'google/organic'
      WHEN traffic_source.source = '(direct)' AND traffic_source.medium = '(none)' THEN 'direct'
      WHEN traffic_source.source = 'google' AND traffic_source.medium = 'cpc' THEN 'google/cpc'
      WHEN traffic_source.source = 'shop.googlemerchandisestore.com' AND traffic_source.medium = 'referral' THEN 'self-referral'
      ELSE '식별불가/기타'
    END AS channel
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
    fc.channel,
    MAX(CASE WHEN e.event_name = 'begin_checkout' AND e.event_date >= fc.first_cart_date THEN 1 ELSE 0 END) AS did_checkout
  FROM first_cart_event fc
  LEFT JOIN events e ON e.user_pseudo_id = fc.user_pseudo_id
  GROUP BY fc.user_pseudo_id, fc.first_cart_date, fc.device_category, fc.channel
),
labeled AS (
  SELECT
    *,
    CASE WHEN first_cart_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '평상시' END AS period
  FROM user_outcome
)
SELECT '디바이스' AS segment_type, device_category AS segment, period,
  COUNT(*) AS users, SUM(did_checkout) AS checkout_users,
  ROUND(SAFE_DIVIDE(SUM(did_checkout), COUNT(*)) * 100, 2) AS cart_to_checkout_rate
FROM labeled
GROUP BY segment, period

UNION ALL

SELECT '채널' AS segment_type, channel AS segment, period,
  COUNT(*) AS users, SUM(did_checkout) AS checkout_users,
  ROUND(SAFE_DIVIDE(SUM(did_checkout), COUNT(*)) * 100, 2) AS cart_to_checkout_rate
FROM labeled
GROUP BY segment, period

ORDER BY segment_type, segment, period
