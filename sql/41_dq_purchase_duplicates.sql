-- 목적: 데이터 품질 점검 ② - purchase 이벤트가 transaction_id 기준으로 중복 기록되어 있는지 확인한다.
-- 매출 합산(ARPU/ARPPU, 채널 매출, 임팩트 추정)이 SUM(revenue) over purchase 이벤트 그대로라서,
-- 같은 주문이 여러 행으로 찍혀 있으면 매출과 구매자 수가 부풀려진다.

WITH p AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS transaction_id,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),
valid AS (
  SELECT * FROM p WHERE transaction_id IS NOT NULL AND transaction_id NOT IN ('', '(not set)')
),
per_txn AS (
  SELECT
    transaction_id,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT user_pseudo_id) AS n_users,
    COUNT(DISTINCT event_date) AS n_dates,
    COUNT(DISTINCT revenue) AS n_distinct_revenue,
    SUM(revenue) AS sum_revenue,
    MAX(revenue) AS max_revenue
  FROM valid
  GROUP BY transaction_id
)
SELECT
  (SELECT COUNT(*) FROM p) AS purchase_events,
  (SELECT COUNTIF(transaction_id IS NULL OR transaction_id IN ('', '(not set)')) FROM p) AS txn_id_missing_rows,
  (SELECT COUNT(*) FROM per_txn) AS distinct_txn_ids,
  COUNTIF(n_rows > 1) AS duplicated_txn_ids,
  SUM(IF(n_rows > 1, n_rows - 1, 0)) AS extra_rows,
  COUNTIF(n_rows > 1 AND n_users > 1) AS dup_with_multiple_users,
  COUNTIF(n_rows > 1 AND n_dates > 1) AS dup_across_multiple_dates,
  COUNTIF(n_rows > 1 AND n_distinct_revenue > 1) AS dup_with_different_revenue,
  ROUND(SUM(IF(n_rows > 1, sum_revenue - max_revenue, 0)), 2) AS inflated_revenue_if_summed,
  (SELECT ROUND(SUM(revenue), 2) FROM p) AS total_revenue_summed_as_is
FROM per_txn
