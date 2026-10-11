-- 목적: Retention 단계 - 실제로 재구매한 고객만 대상으로, 첫 구매일부터 두 번째 구매일까지
-- 며칠 걸렸는지 분포를 확인한다. 3개월 관측기간이 이 카테고리 재구매 주기를 보기에
-- 충분한지 판단하는 근거로 쓴다.
-- 주의: 여기 포함된 건 "이미 재구매에 성공한" 고객뿐이다. 첫 구매가 늦어서 재구매할
-- 시간이 부족했던 고객은 이 분포에 안 잡히므로, 분포가 실제보다 짧은 간격 쪽으로
-- 약간 치우쳐 있을 수 있다(관측 가능한 사람들만 보이는 구조적 한계).

WITH events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
distinct_purchase_dates AS (
  SELECT DISTINCT user_pseudo_id, event_date
  FROM events
  WHERE event_name = 'purchase'
),
ranked AS (
  SELECT
    user_pseudo_id,
    event_date,
    ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_date) AS rn
  FROM distinct_purchase_dates
),
first_purchase AS (
  SELECT user_pseudo_id, event_date AS first_date
  FROM ranked WHERE rn = 1
),
second_purchase AS (
  SELECT user_pseudo_id, event_date AS second_date
  FROM ranked WHERE rn = 2
)
SELECT
  fp.user_pseudo_id,
  fp.first_date,
  sp.second_date,
  DATE_DIFF(sp.second_date, fp.first_date, DAY) AS interval_days
FROM first_purchase fp
JOIN second_purchase sp USING (user_pseudo_id)
ORDER BY interval_days
