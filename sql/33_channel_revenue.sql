-- 목적: Revenue 단계 - Acquisition의 채널별 전환율(13번)을 매출 쪽으로 확장한다.
-- 신규유저를 First-touch 채널로 분류하고, 확정된 7일 어트리뷰션 윈도우 안에서 발생한
-- 매출을 채널별로 합산한다. CAC를 아는 유일한 채널(google/cpc)은 ROAS까지 계산해
-- CAC 분석에서 열어뒀던 "재구매까지 포함하면 회수되는가"의 1차 근사치로 쓴다
-- (단, 여기서도 7일 윈도우 안 매출만 반영하므로 완전한 LTV는 아님).

WITH session_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
    event_name,
    traffic_source.source AS source,
    traffic_source.medium AS medium,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
new_users AS (
  SELECT
    user_pseudo_id,
    MIN(event_date) AS first_date,
    ANY_VALUE(source) AS source,
    ANY_VALUE(medium) AS medium
  FROM session_events
  WHERE session_number = 1 AND session_id IS NOT NULL
  GROUP BY user_pseudo_id
),
purchases AS (
  SELECT user_pseudo_id, event_date, revenue
  FROM session_events
  WHERE event_name = 'purchase'
),
channeled AS (
  SELECT
    nu.user_pseudo_id,
    CASE
      WHEN nu.source = 'google' AND nu.medium = 'organic' THEN 'google/organic'
      WHEN nu.source = '(direct)' AND nu.medium = '(none)' THEN 'direct'
      WHEN nu.source = 'google' AND nu.medium = 'cpc' THEN 'google/cpc'
      WHEN nu.source = 'shop.googlemerchandisestore.com' AND nu.medium = 'referral' THEN 'self-referral'
      ELSE '식별불가/기타'
    END AS channel,
    nu.first_date
  FROM new_users nu
),
window_revenue AS (
  SELECT
    c.channel,
    c.user_pseudo_id,
    SUM(IF(p.event_date IS NOT NULL AND DATE_DIFF(p.event_date, c.first_date, DAY) BETWEEN 0 AND 7, p.revenue, 0)) AS revenue_7d
  FROM channeled c
  LEFT JOIN purchases p USING (user_pseudo_id)
  GROUP BY c.channel, c.user_pseudo_id
)
SELECT
  channel,
  COUNT(*) AS new_users,
  COUNTIF(revenue_7d > 0) AS converters,
  ROUND(SUM(revenue_7d), 2) AS total_revenue_7d,
  ROUND(SAFE_DIVIDE(SUM(revenue_7d), COUNT(*)), 3) AS revenue_per_new_user,
  ROUND(SAFE_DIVIDE(SUM(revenue_7d), COUNTIF(revenue_7d > 0)), 2) AS revenue_per_converter
FROM window_revenue
GROUP BY channel
ORDER BY total_revenue_7d DESC
