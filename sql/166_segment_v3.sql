-- 목적: docs/04 검증2(디바이스/채널)를 평상시 정의 v3(12/1~12/13)로 재계산.
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
    CASE
      WHEN first_cart_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간'
      WHEN first_cart_date BETWEEN '2020-12-01' AND '2020-12-13' THEN '평상시'
      ELSE '사후구간'
    END AS period
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
