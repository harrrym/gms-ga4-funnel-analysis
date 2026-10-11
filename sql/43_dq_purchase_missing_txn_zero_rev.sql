-- 목적: 데이터 품질 점검 ②③ 후속 - transaction_id가 비어있는 purchase(906건)와 revenue=0인 purchase(450건)가
-- 서로 겹치는지, 어떤 성격(중복/무료주문/테스트?)인지 확인한다.

WITH p AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    event_timestamp,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS transaction_id,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
)
SELECT
  CASE
    WHEN transaction_id IS NULL THEN 'txn=NULL'
    WHEN transaction_id = '' THEN 'txn=빈문자열'
    WHEN transaction_id = '(not set)' THEN 'txn=(not set)'
    ELSE 'txn=정상값'
  END AS txn_status,
  IF(revenue = 0, 'revenue=0', 'revenue>0') AS rev_status,
  COUNT(*) AS purchase_rows,
  COUNT(DISTINCT user_pseudo_id) AS users,
  ROUND(SUM(revenue), 2) AS revenue_sum,
  COUNT(*) - COUNT(DISTINCT CONCAT(user_pseudo_id, '|', CAST(event_date AS STRING), '|', CAST(revenue AS STRING))) AS rows_repeating_same_user_date_revenue
FROM p
GROUP BY txn_status, rev_status
ORDER BY txn_status, rev_status
