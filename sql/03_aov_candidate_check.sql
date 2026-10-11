-- 목적: OMTM 후보 중 객단가(AOV)의 변동성을 구매전환율과 비교해, 왜 전환율을 최종 선택했는지 근거를 보강한다.

WITH purchases AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week_start,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS transaction_id,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
)
SELECT
  week_start,
  COUNT(DISTINCT transaction_id) AS transaction_count,
  ROUND(SUM(revenue), 2) AS total_revenue,
  ROUND(SAFE_DIVIDE(SUM(revenue), COUNT(DISTINCT transaction_id)), 2) AS aov
FROM purchases
GROUP BY week_start
ORDER BY week_start
