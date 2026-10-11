-- 목적: "담기기록없음" 결제시작 비율을 평상시(12/1~12/13) vs 하락구간으로 직접 비교 (잔존 한계 수치용).
WITH first_checkout_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_checkout_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'begin_checkout'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp ASC) = 1
),
any_cart AS (
  SELECT DISTINCT user_pseudo_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
)
SELECT
  CASE
    WHEN fc.first_checkout_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간'
    WHEN fc.first_checkout_date BETWEEN '2020-12-01' AND '2020-12-13' THEN '평상시'
    ELSE '사후구간'
  END AS period,
  COUNT(*) AS checkout_users,
  SUM(CASE WHEN ac.user_pseudo_id IS NULL THEN 1 ELSE 0 END) AS no_cart_users,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN ac.user_pseudo_id IS NULL THEN 1 ELSE 0 END), COUNT(*)) * 100, 2) AS no_cart_pct
FROM first_checkout_event fc
LEFT JOIN any_cart ac ON ac.user_pseudo_id = fc.user_pseudo_id
GROUP BY period
ORDER BY period
