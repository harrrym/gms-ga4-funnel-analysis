-- 목적: ARPPU를 평상시 정의 v3(12/1~12/13)로 재계산 (임팩트 추정용).
WITH purchases AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    event_timestamp,
    COALESCE(
      (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'transaction_id'),
      CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS STRING)
    ) AS transaction_id,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),
deduped AS (
  SELECT *
  FROM purchases
  WHERE TRUE
  QUALIFY transaction_id IS NULL
       OR ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY event_timestamp) = 1
),
labeled AS (
  SELECT
    *,
    CASE
      WHEN event_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간'
      WHEN event_date BETWEEN '2020-12-01' AND '2020-12-13' THEN '평상시'
      ELSE '사후구간'
    END AS period
  FROM deduped
)
SELECT
  period,
  COUNT(DISTINCT IF(revenue > 0, user_pseudo_id, NULL)) AS paying_users_valid,
  ROUND(SUM(revenue), 2) AS revenue_total,
  ROUND(SAFE_DIVIDE(SUM(revenue), COUNT(DISTINCT IF(revenue > 0, user_pseudo_id, NULL))), 2) AS arppu
FROM labeled
GROUP BY period
ORDER BY period
