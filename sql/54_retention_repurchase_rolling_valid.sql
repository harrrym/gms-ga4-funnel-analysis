-- 민감도 점검: 원본 쿼리(27_retention_repurchase_rolling.sql)와 동일하되 revenue>0인 purchase만 구매로 인정한다.
-- 원본은 revenue=0 구매(금액·거래번호 기록 누락으로 추정)를 구매로 세는데, 그 가정이 재구매 리텐션 수치를 바꾸는지 확인하기 위함.
-- 같은 날짜 안의 중복 purchase는 first/last purchase date 계산에 영향이 없어 별도 제거하지 않았다.

-- 목적: Retention 단계 - 첫 구매 고객의 주간 코호트별 "재구매" 롤링 리텐션(Day 7/14/30).
-- 코호트 기준을 첫 세션이 아니라 "첫 구매일"로 잡는다 (재구매를 논하려면 첫 구매가 있어야 하므로).
-- 롤링 리텐션: 첫 구매로부터 N일째 또는 그 이후 아무 때나 "또" 구매했는가.
-- 주의(censoring): 26번 쿼리와 동일하게, 첫 구매로부터 N일을 관찰할 시간이 없었던 코호트는
-- 분모(eligible_customers)에서 제외한다.

WITH events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    event_name,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
purchases AS (
  SELECT user_pseudo_id, event_date
  FROM events
  WHERE event_name = 'purchase' AND revenue > 0
),
first_purchase AS (
  SELECT user_pseudo_id, MIN(event_date) AS first_purchase_date
  FROM purchases
  GROUP BY user_pseudo_id
),
last_purchase AS (
  SELECT user_pseudo_id, MAX(event_date) AS last_purchase_date
  FROM purchases
  GROUP BY user_pseudo_id
),
cohort AS (
  SELECT
    fp.user_pseudo_id,
    fp.first_purchase_date,
    DATE_TRUNC(fp.first_purchase_date, WEEK(MONDAY)) AS cohort_week,
    lp.last_purchase_date
  FROM first_purchase fp
  JOIN last_purchase lp USING (user_pseudo_id)
),
checkpoints AS (
  SELECT 7 AS day_n UNION ALL SELECT 14 UNION ALL SELECT 30
),
cohort_size AS (
  SELECT cohort_week, COUNT(*) AS cohort_size
  FROM cohort
  GROUP BY cohort_week
),
eligible AS (
  SELECT
    c.cohort_week,
    ck.day_n,
    DATE_DIFF(DATE('2021-01-31'), c.first_purchase_date, DAY) >= ck.day_n AS has_enough_runway,
    c.last_purchase_date >= DATE_ADD(c.first_purchase_date, INTERVAL ck.day_n DAY) AS retained
  FROM cohort c
  CROSS JOIN checkpoints ck
)
SELECT
  e.cohort_week,
  cs.cohort_size,
  e.day_n,
  COUNTIF(e.has_enough_runway) AS eligible_customers,
  COUNTIF(e.has_enough_runway AND e.retained) AS repurchased_customers,
  ROUND(SAFE_DIVIDE(COUNTIF(e.has_enough_runway AND e.retained), COUNTIF(e.has_enough_runway)) * 100, 2) AS repurchase_rate_pct
FROM eligible e
JOIN cohort_size cs USING (cohort_week)
GROUP BY e.cohort_week, cs.cohort_size, e.day_n
ORDER BY e.cohort_week, e.day_n
