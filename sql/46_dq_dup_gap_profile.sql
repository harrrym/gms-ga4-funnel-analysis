-- 목적: 중복 purchase(같은 transaction_id)가 왜 생기는지 단서를 찾는다.
-- 같은 세션 안에서 바로 이어서 찍혔는지(리로드/이중 전송 의심), 아니면 시간차를 두고 찍혔는지를 본다.

WITH p AS (
  SELECT
    event_timestamp,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sid,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS transaction_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),
g AS (
  SELECT
    transaction_id,
    COUNT(*) AS n,
    COUNT(DISTINCT sid) AS n_sessions,
    COUNT(DISTINCT event_timestamp) AS n_ts,
    (MAX(event_timestamp) - MIN(event_timestamp)) / 1000000 AS gap_sec
  FROM p
  WHERE transaction_id IS NOT NULL AND transaction_id NOT IN ('', '(not set)')
  GROUP BY transaction_id
  HAVING n > 1
)
SELECT
  COUNT(*) AS dup_txn_ids,
  COUNTIF(n_sessions = 1) AS same_session,
  COUNTIF(n_ts = 1) AS identical_timestamp,
  COUNTIF(gap_sec > 0 AND gap_sec <= 10) AS gap_1_to_10s,
  COUNTIF(gap_sec > 10 AND gap_sec <= 60) AS gap_10_to_60s,
  COUNTIF(gap_sec > 60 AND gap_sec <= 3600) AS gap_1min_to_1h,
  COUNTIF(gap_sec > 3600) AS gap_over_1h,
  ROUND(APPROX_QUANTILES(gap_sec, 100)[OFFSET(50)], 1) AS median_gap_sec,
  ROUND(MAX(gap_sec), 1) AS max_gap_sec
FROM g
