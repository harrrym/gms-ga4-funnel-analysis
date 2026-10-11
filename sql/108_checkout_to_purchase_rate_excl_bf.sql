-- 목적(민감도 체크): 100번(OMTM 다리, checkout->purchase 43.43%->54.92%)이 블랙프라이데이 주
-- (11/23~11/30) 포함 여부에 영향을 받는지 스팟체크.

WITH first_checkout_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_checkout_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'begin_checkout'
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
    fc.first_checkout_date,
    MAX(CASE WHEN e.event_name = 'purchase' AND e.event_date >= fc.first_checkout_date THEN 1 ELSE 0 END) AS did_purchase
  FROM first_checkout_event fc
  LEFT JOIN events e ON e.user_pseudo_id = fc.user_pseudo_id
  GROUP BY fc.user_pseudo_id, fc.first_checkout_date
),
labeled AS (
  SELECT
    *,
    CASE
      WHEN first_checkout_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간'
      WHEN first_checkout_date BETWEEN '2020-11-23' AND '2020-11-30' THEN '블프구간'
      ELSE '평상시(블프제외)'
    END AS period
  FROM user_outcome
)
SELECT
  period,
  COUNT(*) AS users,
  SUM(did_purchase) AS purchased_users,
  ROUND(SAFE_DIVIDE(SUM(did_purchase), COUNT(*)) * 100, 2) AS checkout_to_purchase_rate
FROM labeled
GROUP BY period
ORDER BY period
