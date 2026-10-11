-- [transaction_id 통합 키] transaction_id는 2020-11-01~11-12 구간에서는 int_value 칸에, 이후에는 string_value 칸에 저장돼 있다.
-- string_value만 읽으면 int_value 칸의 456행을 "번호 없음"으로 잘못 처리하므로 두 칸을 COALESCE로 합쳐 하나의 키로 쓴다 (docs/05 참고).
-- 목적: 데이터 품질 점검 ④ - 32번 주간 ARPPU를 "정제된 구매" 기준으로 다시 계산해 기존 수치와 비교한다.
-- 정제 1) transaction_id가 같은 purchase 행은 1건만 남긴다 (검증 결과: 중복은 전부 같은 유저·같은 날짜·같은 금액의 완전 중복).
-- 정제 2) revenue > 0인 구매만 구매자로 센다.
-- transaction_id가 NULL인 행은 파라미터 자체가 없는 revenue=0 구매 450건뿐이라 그대로 둔다.

WITH purchases AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week_start,
    user_pseudo_id,
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
deduped AS (
  SELECT *
  FROM purchases
  WHERE TRUE
  QUALIFY transaction_id IS NULL
       OR ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY event_timestamp) = 1
)
SELECT
  week_start,
  (SELECT COUNT(DISTINCT user_pseudo_id) FROM purchases p WHERE p.week_start = d.week_start) AS paying_users_raw,
  (SELECT ROUND(SUM(revenue), 2) FROM purchases p WHERE p.week_start = d.week_start) AS revenue_raw,
  COUNT(DISTINCT IF(revenue > 0, user_pseudo_id, NULL)) AS paying_users_valid,
  ROUND(SUM(revenue), 2) AS revenue_deduped
FROM deduped d
GROUP BY week_start
ORDER BY week_start
