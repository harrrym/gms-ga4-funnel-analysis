-- 목적: Retention 단계 - 코호트로 쪼개지 않고 전체 첫구매고객 기준으로 재구매 롤링 리텐션 곡선(Day 1~60)을 그린다.
-- 27번 쿼리와 같은 censoring 처리를 쓰되, 주간 코호트로 쪼개지 않고 전체를 하나로 합쳐서 더 촘촘한 일별 곡선을 얻는다.

WITH events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
purchases AS (
  SELECT user_pseudo_id, event_date
  FROM events
  WHERE event_name = 'purchase'
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
  SELECT fp.user_pseudo_id, fp.first_purchase_date, lp.last_purchase_date
  FROM first_purchase fp
  JOIN last_purchase lp USING (user_pseudo_id)
),
day_series AS (
  SELECT day_n FROM UNNEST(GENERATE_ARRAY(1, 60)) AS day_n
),
eligible AS (
  SELECT
    ds.day_n,
    DATE_DIFF(DATE('2021-01-31'), c.first_purchase_date, DAY) >= ds.day_n AS has_enough_runway,
    c.last_purchase_date >= DATE_ADD(c.first_purchase_date, INTERVAL ds.day_n DAY) AS retained
  FROM cohort c
  CROSS JOIN day_series ds
)
SELECT
  day_n,
  COUNTIF(has_enough_runway) AS eligible_customers,
  COUNTIF(has_enough_runway AND retained) AS repurchased_customers,
  ROUND(SAFE_DIVIDE(COUNTIF(has_enough_runway AND retained), COUNTIF(has_enough_runway)) * 100, 3) AS repurchase_rate_pct
FROM eligible
GROUP BY day_n
ORDER BY day_n
