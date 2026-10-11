-- [transaction_id 통합 키] transaction_id는 2020-11-01~11-12 구간에서는 int_value 칸에, 이후에는 string_value 칸에 저장돼 있다.
-- string_value만 읽으면 int_value 칸의 456행을 "번호 없음"으로 잘못 처리하므로 두 칸을 COALESCE로 합쳐 하나의 키로 쓴다 (docs/05 참고).
-- 목적: 03번 AOV의 정제본. 03번은 transaction_id를 string_value 칸에서만 읽어 int_value 칸의 456행이 분모에서 빠진 채
-- 매출과 중복 매출을 더해 AOV가 과대했다 (2020-11-02 주는 거래 건수 0인데 매출 $21,820).
-- 정제 기준: 같은 transaction_id는 1건만 남기고, 금액이 있는(revenue>0) 구매 1행을 주문 1건으로 센다.
-- transaction_id가 NULL인 행(파라미터가 없는 revenue=0 구매)은 revenue>0 조건에서 제외된다.

WITH purchases_raw AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week_start,
    event_timestamp,
    COALESCE(
      (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'transaction_id'),
      CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS STRING)
    ) AS transaction_id,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),
purchases AS (
  SELECT *
  FROM purchases_raw
  WHERE TRUE
  QUALIFY transaction_id IS NULL
       OR ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY event_timestamp) = 1
)
SELECT
  week_start,
  COUNTIF(revenue > 0) AS orders_clean,
  ROUND(SUM(revenue), 2) AS revenue_clean,
  ROUND(SAFE_DIVIDE(SUM(revenue), COUNTIF(revenue > 0)), 2) AS aov_clean
FROM purchases
GROUP BY week_start
ORDER BY week_start
