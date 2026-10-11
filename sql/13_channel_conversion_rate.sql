-- 목적: 채널별 볼륨이 아닌 "품질"(전환율)을 확인한다.
-- 신규 유저(ga_session_number=1)를 채널별로 나누고, 그 중 7일 이내(확정된 어트리뷰션 윈도우)에
-- 구매까지 이어진 비율을 계산한다. First-touch 채널 기준.

WITH session_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
    event_name,
    traffic_source.source AS source,
    traffic_source.medium AS medium
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
first_purchase AS (
  SELECT
    user_pseudo_id,
    MIN(event_date) AS purchase_date
  FROM session_events
  WHERE event_name = 'purchase'
  GROUP BY user_pseudo_id
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
    CASE
      WHEN fp.purchase_date IS NOT NULL AND DATE_DIFF(fp.purchase_date, nu.first_date, DAY) BETWEEN 0 AND 7
      THEN 1 ELSE 0
    END AS converted_within_7d
  FROM new_users nu
  LEFT JOIN first_purchase fp USING (user_pseudo_id)
)
SELECT
  channel,
  COUNT(*) AS new_users,
  SUM(converted_within_7d) AS converted,
  ROUND(SAFE_DIVIDE(SUM(converted_within_7d), COUNT(*)) * 100, 3) AS conversion_rate_pct
FROM channeled
GROUP BY channel
ORDER BY conversion_rate_pct DESC
