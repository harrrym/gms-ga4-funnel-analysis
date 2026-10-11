-- 목적: transaction_id가 시기별로 어느 칸(string_value / int_value)에 저장돼 있는지 원본 행 몇 개로 직접 보여준다 (설명용 샘플).
-- 유저 식별값은 가져오지 않는다.

WITH p AS (
  SELECT
    event_date,
    event_timestamp,
    ecommerce.purchase_revenue_in_usd AS revenue,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS string_value,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS int_value,
    EXISTS(SELECT 1 FROM UNNEST(event_params) WHERE key = 'transaction_id') AS has_txn_param
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
)
SELECT * FROM (
  SELECT '1) 11월 초' AS period_label, event_date, string_value, int_value, revenue
  FROM p WHERE event_date = '20201105' AND int_value IS NOT NULL ORDER BY event_timestamp LIMIT 3
)
UNION ALL
SELECT * FROM (
  SELECT '2) 12월' AS period_label, event_date, string_value, int_value, revenue
  FROM p WHERE event_date = '20201215' AND string_value IS NOT NULL ORDER BY event_timestamp LIMIT 3
)
UNION ALL
SELECT * FROM (
  SELECT '3) 번호 파라미터 없음' AS period_label, event_date, string_value, int_value, revenue
  FROM p WHERE NOT has_txn_param ORDER BY event_timestamp LIMIT 3
)
ORDER BY period_label, event_date
