-- 목적: 새 기간 정의(기준선 12/1~12/13, 전환 12/14~12/18, 하락 12/19~1/11, 회복기 1/12~1/31)별 구매 세션당 매출.
-- sql/184와 같은 중복 제거(transaction_id), 금액>0 구매 세션 기준. 구매 이벤트 날짜로 기간 구분.
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
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131' AND event_name = 'purchase'
),
deduped AS (
  SELECT * FROM purchases WHERE TRUE
  QUALIFY transaction_id IS NULL OR ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY event_timestamp) = 1
)
SELECT
  CASE
    WHEN event_date BETWEEN '2020-12-01' AND '2020-12-13' THEN '1 기준선'
    WHEN event_date BETWEEN '2020-12-14' AND '2020-12-18' THEN '2 전환'
    WHEN event_date BETWEEN '2020-12-19' AND '2021-01-11' THEN '3 하락'
    ELSE '4 회복기'
  END AS period,
  COUNT(DISTINCT session_key) AS purchase_sessions_all,
  COUNT(DISTINCT IF(revenue > 0, session_key, NULL)) AS purchase_sessions_valid,
  ROUND(SUM(revenue), 2) AS revenue_total,
  ROUND(SAFE_DIVIDE(SUM(revenue), COUNT(DISTINCT IF(revenue > 0, session_key, NULL))), 2) AS revenue_per_valid_session
FROM deduped GROUP BY period ORDER BY period
