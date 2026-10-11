-- 목적: 가설(연말연시 할인부재/구매유예) ICE 채점용 가벼운 집계.
-- "미루는 것"이 맞다면, 실제로 결제까지 간 유저들 중에서도 담고 나서 결제시작까지 걸린 기간이
-- 하락구간에 더 길어야 한다. 36번과 동일한 유저 단위 코호트에서, 전환한 유저만 대상으로 지연일수를 본다.
-- 주의: 관측기간이 2021-01-31까지라 하락구간 후반부 코호트일수록 관측 가능한 최대 지연일수 자체가 짧다(censoring).

WITH first_cart_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_cart_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp ASC) = 1
),
first_checkout_after AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'begin_checkout'
),
joined AS (
  SELECT
    fc.user_pseudo_id,
    fc.first_cart_date,
    MIN(fca.event_date) AS first_checkout_date
  FROM first_cart_event fc
  JOIN first_checkout_after fca
    ON fca.user_pseudo_id = fc.user_pseudo_id
    AND fca.event_date >= fc.first_cart_date
  GROUP BY fc.user_pseudo_id, fc.first_cart_date
),
labeled AS (
  SELECT
    *,
    DATE_DIFF(first_checkout_date, first_cart_date, DAY) AS lag_days,
    CASE WHEN first_cart_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '평상시' END AS period
  FROM joined
)
SELECT
  period,
  COUNT(*) AS converted_users,
  ROUND(AVG(lag_days), 2) AS avg_lag_days,
  APPROX_QUANTILES(lag_days, 2)[OFFSET(1)] AS median_lag_days,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN lag_days = 0 THEN 1 ELSE 0 END), COUNT(*)) * 100, 2) AS pct_same_day,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN lag_days >= 7 THEN 1 ELSE 0 END), COUNT(*)) * 100, 2) AS pct_lag_7d_plus
FROM labeled
GROUP BY period
