-- 목적: 어트리뷰션 윈도우를 감으로 정하지 않기 위해, 실제 구매자의 "첫 세션 ~ 첫 구매" 간격을 측정한다.
-- 첫 세션(ga_session_number=1)이 데이터 기간 안에서 관측된 유저만 대상으로 한다 (첫 방문 시점을 알아야 간격 계산 가능).
-- 주의: 이 "첫 세션"은 쿠키 기반 식별자의 첫 세션이지 진짜 생애 첫 방문 보장이 아니다.
-- 쿠키 리셋된 재방문자가 일부 섞여있을 수 있다 (docs/03_aarrr_diagnosis.md 참고).

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
first_touch AS (
  SELECT user_pseudo_id, MIN(event_date) AS first_date
  FROM session_events
  WHERE session_number = 1 AND session_id IS NOT NULL
  GROUP BY user_pseudo_id
),
first_purchase AS (
  SELECT
    user_pseudo_id,
    MIN(event_date) AS purchase_date,
    MIN(session_number) AS purchase_session_number
  FROM session_events
  WHERE event_name = 'purchase'
  GROUP BY user_pseudo_id
)
SELECT
  DATE_DIFF(fp.purchase_date, ft.first_date, DAY) AS gap_days,
  fp.purchase_session_number
FROM first_touch ft
JOIN first_purchase fp USING (user_pseudo_id)
WHERE fp.purchase_date >= ft.first_date
