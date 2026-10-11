-- 목적: 중복 purchase가 특정 날짜에 몰려 있는지 확인한다 (11/16, 11/23 주에 매출 부풀림이 컸던 이유).

WITH p AS (
  SELECT
    event_date,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS transaction_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),
g AS (
  SELECT transaction_id, event_date, COUNT(*) AS n
  FROM p
  WHERE transaction_id IS NOT NULL AND transaction_id NOT IN ('', '(not set)')
  GROUP BY transaction_id, event_date
)
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  COUNT(*) AS txn_ids,
  SUM(n - 1) AS extra_rows,
  COUNTIF(n > 1) AS duplicated_txn_ids
FROM g
GROUP BY event_date
HAVING extra_rows > 0
ORDER BY extra_rows DESC
LIMIT 15
