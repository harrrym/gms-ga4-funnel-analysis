-- 목적: Activation의 "첫 세션 검색 사용 -> 7일 내 구매전환" 발견을 Retention까지 연결한다.
-- 이미 7일 내 구매전환에 성공한 고객만 놓고, 첫 세션 검색 여부에 따라 재구매율(롤링, Day 7/14/30)이
-- 다른지 확인한다. censoring 처리는 27번 쿼리와 동일하게, 각 (그룹, Day N) 조합마다
-- 실제로 관찰할 시간이 있었던 고객만 분모에 포함한다.

WITH session_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
first_session_behavior AS (
  SELECT
    user_pseudo_id,
    MIN(event_date) AS first_date,
    MAX(CASE WHEN event_name = 'view_search_results' THEN 1 ELSE 0 END) AS did_search
  FROM session_events
  WHERE session_number = 1 AND session_id IS NOT NULL
  GROUP BY user_pseudo_id
),
first_purchase AS (
  SELECT user_pseudo_id, MIN(event_date) AS first_purchase_date
  FROM session_events
  WHERE event_name = 'purchase'
  GROUP BY user_pseudo_id
),
last_purchase AS (
  SELECT user_pseudo_id, MAX(event_date) AS last_purchase_date
  FROM session_events
  WHERE event_name = 'purchase'
  GROUP BY user_pseudo_id
),
converters_7d AS (
  -- Activation 원래 정의와 동일: 첫 세션으로부터 7일 이내에 구매전환한 사람만
  SELECT
    fsb.user_pseudo_id,
    fsb.did_search,
    fp.first_purchase_date,
    lp.last_purchase_date
  FROM first_session_behavior fsb
  JOIN first_purchase fp USING (user_pseudo_id)
  JOIN last_purchase lp USING (user_pseudo_id)
  WHERE DATE_DIFF(fp.first_purchase_date, fsb.first_date, DAY) BETWEEN 0 AND 7
),
checkpoints AS (
  SELECT 7 AS day_n UNION ALL SELECT 14 UNION ALL SELECT 30
),
eligible AS (
  SELECT
    c.did_search,
    ck.day_n,
    DATE_DIFF(DATE('2021-01-31'), c.first_purchase_date, DAY) >= ck.day_n AS has_enough_runway,
    c.last_purchase_date >= DATE_ADD(c.first_purchase_date, INTERVAL ck.day_n DAY) AS retained
  FROM converters_7d c
  CROSS JOIN checkpoints ck
)
SELECT
  did_search,
  day_n,
  COUNTIF(has_enough_runway) AS eligible_customers,
  COUNTIF(has_enough_runway AND retained) AS repurchased_customers,
  ROUND(SAFE_DIVIDE(COUNTIF(has_enough_runway AND retained), COUNTIF(has_enough_runway)) * 100, 3) AS repurchase_rate_pct
FROM eligible
GROUP BY did_search, day_n
ORDER BY did_search, day_n
