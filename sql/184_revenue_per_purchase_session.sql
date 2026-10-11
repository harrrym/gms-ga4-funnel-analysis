-- 목적: OMTM(세션 단위) 임팩트 추정용. 기간별 구매 세션당 매출 (sql/164와 같은 중복 제거, 금액>0 구매만).
WITH purchases AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    event_timestamp,
    COALESCE(
      (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'transaction_id'),
      CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS STRING)
    ) AS transaction_id,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210111' AND event_name = 'purchase'
),
deduped AS (
  SELECT * FROM purchases WHERE TRUE
  QUALIFY transaction_id IS NULL OR ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY event_timestamp) = 1
)
SELECT
  CASE WHEN event_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '12월 초' END AS period,
  COUNT(DISTINCT session_key) AS purchase_sessions_all,
  COUNT(DISTINCT IF(revenue > 0, session_key, NULL)) AS purchase_sessions_valid,
  ROUND(SUM(revenue), 2) AS revenue_total,
  ROUND(SAFE_DIVIDE(SUM(revenue), COUNT(DISTINCT IF(revenue > 0, session_key, NULL))), 2) AS revenue_per_valid_session
FROM deduped
GROUP BY period ORDER BY period
