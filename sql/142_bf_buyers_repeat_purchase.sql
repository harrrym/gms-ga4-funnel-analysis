-- 목적: "블프 할인 때 당겨서 구매" 가설 검증 - 블프구간 구매자가 하락구간에 다시 구매하는 비율이
-- 평상시(블프 제외) 구매자보다 낮은지 확인.

WITH purchase_events AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),
user_groups AS (
  SELECT
    user_pseudo_id,
    LOGICAL_OR(event_date BETWEEN '2020-11-23' AND '2020-11-30') AS bought_in_bf,
    LOGICAL_OR(event_date < '2020-12-14' AND NOT (event_date BETWEEN '2020-11-23' AND '2020-11-30')) AS bought_in_normal,
    LOGICAL_OR(event_date BETWEEN '2020-12-14' AND '2021-01-11') AS bought_in_decline
  FROM purchase_events
  GROUP BY user_pseudo_id
)
SELECT
  CASE
    WHEN bought_in_bf THEN '블프구간 구매자'
    WHEN bought_in_normal THEN '평상시(블프제외) 구매자'
    ELSE '해당없음'
  END AS group_label,
  COUNT(*) AS users,
  SUM(CASE WHEN bought_in_decline THEN 1 ELSE 0 END) AS repeat_in_decline,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN bought_in_decline THEN 1 ELSE 0 END), COUNT(*)) * 100, 2) AS repeat_rate_pct
FROM user_groups
WHERE bought_in_bf OR bought_in_normal
GROUP BY group_label
ORDER BY group_label
