-- 목적: Revenue 단계 - CAC 분석에서 열어뒀던 질문("재구매까지 포함하면 회수되는가")에
-- 방향성만 빠르게 답한다. google/cpc로 유입된 신규유저의 3개월 관측기간 내 누적 매출(LTR)을
-- 계산해 추정 CAC($104.62, Acquisition 참고)와 비교한다.
-- 주의: 정밀한 값이 아니라 방향성 확인용. 늦게 유입된 유저는 관측 기간이 짧아 LTR이
-- 과소추정될 수 있다는 censoring 한계를 그대로 안고 간다(Retention에서 썼던 정밀 보정은 생략).

WITH session_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
    event_name,
    traffic_source.source AS source,
    traffic_source.medium AS medium,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
cpc_new_users AS (
  SELECT user_pseudo_id, MIN(event_date) AS first_date
  FROM session_events
  WHERE session_number = 1 AND session_id IS NOT NULL
    AND source = 'google' AND medium = 'cpc'
  GROUP BY user_pseudo_id
),
user_revenue AS (
  SELECT
    cnu.user_pseudo_id,
    SUM(IF(se.event_name = 'purchase', se.revenue, 0)) AS ltr
  FROM cpc_new_users cnu
  LEFT JOIN session_events se USING (user_pseudo_id)
  GROUP BY cnu.user_pseudo_id
)
SELECT
  COUNT(*) AS cpc_new_users,
  COUNTIF(ltr > 0) AS cpc_converters,
  ROUND(SUM(ltr), 2) AS total_ltr,
  ROUND(AVG(ltr), 3) AS avg_ltr_per_new_user,
  ROUND(SAFE_DIVIDE(SUM(ltr), COUNTIF(ltr > 0)), 2) AS avg_ltr_per_converter
FROM user_revenue
