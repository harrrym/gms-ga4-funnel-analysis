-- 목적: 60번에서 transaction_id 456건이 string_value가 아니라 int_value 칸에 들어 있음을 발견했다.
-- purchase 이벤트를 transaction_id가 어느 타입 칸에 있는지(string/int/둘 다/없음)로 나눠,
-- 지난번 "transaction_id가 없다"고 판단한 456행(revenue>0)이 실제로는 int_value에 값이 있는 행인지 확인한다.

WITH p AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS txn_s,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS txn_i,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
)
SELECT
  CASE
    WHEN txn_s IS NOT NULL AND txn_i IS NOT NULL THEN '둘 다'
    WHEN txn_s IS NOT NULL THEN 'string_value만'
    WHEN txn_i IS NOT NULL THEN 'int_value만'
    ELSE 'transaction_id 파라미터 없음'
  END AS txn_location,
  COUNT(*) AS purchase_rows,
  COUNTIF(revenue > 0) AS rows_revenue_positive,
  COUNTIF(revenue = 0) AS rows_revenue_zero,
  ROUND(SUM(revenue), 2) AS revenue_sum,
  MIN(event_date) AS min_date,
  MAX(event_date) AS max_date
FROM p
GROUP BY txn_location
ORDER BY purchase_rows DESC
