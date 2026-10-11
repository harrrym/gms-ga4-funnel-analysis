-- 목적: 전처리 점검 - purchase의 transaction_id 형식이 균일한지 확인한다.
-- 숫자는 9, 영문자는 a로 치환한 "형식 서명(signature)"별로 묶어, 서로 다른 형식이 섞여 있는지 본다.

WITH t AS (
  SELECT (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS txn
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
)
SELECT
  CASE WHEN txn IS NULL THEN '(NULL)'
       ELSE REGEXP_REPLACE(REGEXP_REPLACE(txn, r'[0-9]', '9'), r'[A-Za-z]', 'a') END AS signature,
  COUNT(*) AS n,
  COUNT(DISTINCT txn) AS distinct_txn,
  MIN(LENGTH(txn)) AS min_len,
  MAX(LENGTH(txn)) AS max_len,
  COUNTIF(txn != TRIM(txn)) AS with_edge_whitespace,
  ANY_VALUE(txn) AS example
FROM t
GROUP BY signature
ORDER BY n DESC
LIMIT 20
