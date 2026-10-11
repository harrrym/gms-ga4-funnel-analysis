-- [transaction_id 통합 키] transaction_id는 2020-11-01~11-12 구간에서는 int_value 칸에, 이후에는 string_value 칸에 저장돼 있다.
-- string_value만 읽으면 int_value 칸의 456행을 "번호 없음"으로 잘못 처리하므로 두 칸을 COALESCE로 합쳐 하나의 키로 쓴다 (docs/05 참고).
-- 목적: 32번 ARPU/ARPPU의 정제본. 데이터 품질 점검(docs/05) 결과를 반영한다.
-- 정제 1) 같은 transaction_id의 purchase는 1건만 남긴다 (중복은 전부 같은 유저·같은 날짜·같은 금액인 완전 중복).
-- 정제 2) ARPPU의 분모는 금액이 있는(revenue>0) 구매자로 한다 (revenue=0 구매는 가격이 기록되지 않은 것).
-- transaction_id가 NULL인 행은 파라미터 자체가 없는 revenue=0 구매 450건뿐이라 그대로 둔다.
-- ARPU 분모(전체 유저)는 원본과 동일하다. 32번 원본과 나란히 비교할 수 있게 paying_users_raw도 같이 낸다.

WITH all_events AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week_start,
    user_pseudo_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
purchases AS (
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
clean AS (
  SELECT *
  FROM purchases
  WHERE TRUE
  QUALIFY transaction_id IS NULL
       OR ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY event_timestamp) = 1
),
u_weekly AS (
  SELECT week_start, COUNT(DISTINCT user_pseudo_id) AS total_users FROM all_events GROUP BY week_start
),
u_overall AS (
  SELECT COUNT(DISTINCT user_pseudo_id) AS total_users FROM all_events
),
p_weekly AS (
  SELECT
    week_start,
    COUNT(DISTINCT user_pseudo_id) AS paying_users_raw,
    COUNT(DISTINCT IF(revenue > 0, user_pseudo_id, NULL)) AS paying_users_valid,
    SUM(revenue) AS revenue_clean
  FROM clean
  GROUP BY week_start
),
p_overall AS (
  SELECT
    COUNT(DISTINCT user_pseudo_id) AS paying_users_raw,
    COUNT(DISTINCT IF(revenue > 0, user_pseudo_id, NULL)) AS paying_users_valid,
    SUM(revenue) AS revenue_clean
  FROM clean
)
SELECT
  CAST(NULL AS DATE) AS week_start,
  u.total_users, p.paying_users_raw, p.paying_users_valid,
  ROUND(p.revenue_clean, 2) AS revenue_clean,
  ROUND(SAFE_DIVIDE(p.revenue_clean, u.total_users), 3) AS arpu,
  ROUND(SAFE_DIVIDE(p.revenue_clean, p.paying_users_valid), 3) AS arppu
FROM u_overall u, p_overall p
UNION ALL
SELECT
  w.week_start,
  w.total_users, p.paying_users_raw, p.paying_users_valid,
  ROUND(p.revenue_clean, 2),
  ROUND(SAFE_DIVIDE(p.revenue_clean, w.total_users), 3),
  ROUND(SAFE_DIVIDE(p.revenue_clean, p.paying_users_valid), 3)
FROM u_weekly w
LEFT JOIN p_weekly p USING (week_start)
ORDER BY week_start IS NULL DESC, week_start
