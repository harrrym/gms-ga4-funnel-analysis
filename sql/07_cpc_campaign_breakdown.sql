-- 목적: google/cpc(유료광고) 채널의 캠페인명(traffic_source.name) 세부 확인.
-- 캠페인 단위로 신규유입을 얼마나 데려왔는지 볼 수 있는지 확인한다.

WITH first_sessions AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
    traffic_source.source AS source,
    traffic_source.medium AS medium,
    traffic_source.name AS campaign_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
new_users AS (
  SELECT
    user_pseudo_id,
    session_id,
    ANY_VALUE(source) AS source,
    ANY_VALUE(medium) AS medium,
    ANY_VALUE(campaign_name) AS campaign_name
  FROM first_sessions
  WHERE session_id IS NOT NULL AND session_number = 1
  GROUP BY user_pseudo_id, session_id
)
SELECT
  source,
  medium,
  campaign_name,
  COUNT(*) AS new_users
FROM new_users
WHERE medium IN ('cpc', 'organic', 'referral')
GROUP BY source, medium, campaign_name
ORDER BY medium, new_users DESC
