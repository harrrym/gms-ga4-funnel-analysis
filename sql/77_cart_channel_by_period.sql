-- 목적: 가설(유입 채널 믹스 변화) ICE 채점용 가벼운 집계.
-- 채널 버킷 정의는 sql/13_channel_conversion_rate.sql과 동일하게 맞춤(일관성 유지).
-- 첫 add_to_cart 이벤트 시점의 traffic_source를 채널로 사용 (36번과 동일한 유저 단위 코호트 방법론).

WITH first_cart_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_cart_date,
    traffic_source.source AS source,
    traffic_source.medium AS medium
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
channeled AS (
  SELECT
    fc.user_pseudo_id,
    fc.first_cart_date,
    CASE
      WHEN fc.source = 'google' AND fc.medium = 'organic' THEN 'google/organic'
      WHEN fc.source = '(direct)' AND fc.medium = '(none)' THEN 'direct'
      WHEN fc.source = 'google' AND fc.medium = 'cpc' THEN 'google/cpc'
      WHEN fc.source = 'shop.googlemerchandisestore.com' AND fc.medium = 'referral' THEN 'self-referral'
      ELSE '식별불가/기타'
    END AS channel
  FROM first_cart_event fc
),
user_outcome AS (
  SELECT
    c.user_pseudo_id,
    c.first_cart_date,
    c.channel,
    MAX(CASE WHEN e.event_name = 'begin_checkout' AND e.event_date >= c.first_cart_date THEN 1 ELSE 0 END) AS did_checkout
  FROM channeled c
  LEFT JOIN events e ON e.user_pseudo_id = c.user_pseudo_id
  GROUP BY c.user_pseudo_id, c.first_cart_date, c.channel
),
labeled AS (
  SELECT
    *,
    CASE WHEN first_cart_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '평상시' END AS period
  FROM user_outcome
)
SELECT
  channel,
  period,
  COUNT(*) AS users,
  SUM(did_checkout) AS checkout_users,
  ROUND(SAFE_DIVIDE(SUM(did_checkout), COUNT(*)) * 100, 2) AS cart_to_checkout_rate,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY period), 2) AS pct_of_period_cart_users
FROM labeled
GROUP BY channel, period
ORDER BY period, users DESC
