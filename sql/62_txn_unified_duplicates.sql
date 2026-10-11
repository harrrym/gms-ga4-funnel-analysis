-- 목적: transaction_id를 string_value와 int_value 어느 칸에 있든 하나의 키로 통합했을 때의 중복 현황을 다시 계산한다.
-- 41번은 string_value만 읽어서 int_value 칸에 있는 456행을 "transaction_id 없음"으로 놓쳤다.
-- 통합 키 = COALESCE(string_value, CAST(int_value AS STRING)). 서로 다른 타입 칸에 있지만 같은 주문번호인 중복(cross_type)도 같이 본다.

WITH p AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS txn_s,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS txn_i,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),
k AS (
  SELECT
    *,
    COALESCE(txn_s, CAST(txn_i AS STRING)) AS txn,
    IF(txn_s IS NOT NULL, 's', 'i') AS type_used
  FROM p
  WHERE COALESCE(txn_s, CAST(txn_i AS STRING)) IS NOT NULL
),
g AS (
  SELECT
    txn,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT type_used) AS n_types,
    COUNT(DISTINCT user_pseudo_id) AS n_users,
    COUNT(DISTINCT event_date) AS n_dates,
    COUNT(DISTINCT revenue) AS n_revenue_values,
    SUM(revenue) AS sum_revenue,
    MAX(revenue) AS max_revenue
  FROM k
  GROUP BY txn
)
SELECT
  (SELECT COUNT(*) FROM p) AS purchase_rows,
  (SELECT COUNT(*) FROM p WHERE COALESCE(txn_s, CAST(txn_i AS STRING)) IS NULL) AS rows_without_any_txn,
  COUNT(*) AS distinct_txn_unified,
  COUNTIF(n_rows > 1) AS duplicated_txn_ids,
  SUM(IF(n_rows > 1, n_rows - 1, 0)) AS extra_rows,
  COUNTIF(n_rows > 1 AND n_types > 1) AS cross_type_duplicates,
  COUNTIF(n_rows > 1 AND n_users > 1) AS dup_with_multiple_users,
  COUNTIF(n_rows > 1 AND n_dates > 1) AS dup_across_multiple_dates,
  COUNTIF(n_rows > 1 AND n_revenue_values > 1) AS dup_with_different_revenue,
  ROUND(SUM(IF(n_rows > 1, sum_revenue - max_revenue, 0)), 2) AS inflated_revenue_if_summed
FROM g
