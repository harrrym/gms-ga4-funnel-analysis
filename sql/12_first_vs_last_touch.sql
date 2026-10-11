-- 목적: 확정된 7일 어트리뷰션 윈도우 안에서, 구매를 First-touch(첫 유입 채널)와
-- Last-touch(구매 직전 세션의 채널) 기준으로 각각 귀속시켰을 때 채널별 비중이 어떻게 달라지는지 비교한다.
-- 대상: 첫 세션(ga_session_number=1)이 관측되고, 그로부터 7일 이내에 첫 구매를 한 유저.

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
first_touch AS (
  SELECT
    user_pseudo_id,
    MIN(event_date) AS first_date,
    ANY_VALUE(source) AS first_source,
    ANY_VALUE(medium) AS first_medium
  FROM session_events
  WHERE session_number = 1 AND session_id IS NOT NULL
  GROUP BY user_pseudo_id
),
first_purchase AS (
  SELECT
    user_pseudo_id,
    event_date AS purchase_date,
    source AS last_source,
    medium AS last_medium
  FROM session_events
  WHERE event_name = 'purchase'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_date) = 1
),
attributed AS (
  SELECT
    CASE
      WHEN ft.first_source = 'google' AND ft.first_medium = 'organic' THEN 'google/organic'
      WHEN ft.first_source = '(direct)' AND ft.first_medium = '(none)' THEN 'direct'
      WHEN ft.first_source = 'google' AND ft.first_medium = 'cpc' THEN 'google/cpc'
      WHEN ft.first_source = 'shop.googlemerchandisestore.com' AND ft.first_medium = 'referral' THEN 'self-referral'
      ELSE '식별불가/기타'
    END AS first_touch_channel,
    CASE
      WHEN pe.last_source = 'google' AND pe.last_medium = 'organic' THEN 'google/organic'
      WHEN pe.last_source = '(direct)' AND pe.last_medium = '(none)' THEN 'direct'
      WHEN pe.last_source = 'google' AND pe.last_medium = 'cpc' THEN 'google/cpc'
      WHEN pe.last_source = 'shop.googlemerchandisestore.com' AND pe.last_medium = 'referral' THEN 'self-referral'
      ELSE '식별불가/기타'
    END AS last_touch_channel
  FROM first_touch ft
  JOIN first_purchase pe USING (user_pseudo_id)
  WHERE DATE_DIFF(pe.purchase_date, ft.first_date, DAY) BETWEEN 0 AND 7
)
SELECT
  channel,
  COUNTIF(model = 'first_touch') AS first_touch_purchases,
  COUNTIF(model = 'last_touch') AS last_touch_purchases
FROM (
  SELECT first_touch_channel AS channel, 'first_touch' AS model FROM attributed
  UNION ALL
  SELECT last_touch_channel AS channel, 'last_touch' AS model FROM attributed
)
GROUP BY channel
ORDER BY first_touch_purchases DESC
