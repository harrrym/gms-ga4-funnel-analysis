-- 목적: checkout->purchase 전환율을 "이벤트 단위"(모든 begin_checkout 이벤트, 중복 포함)로 계산해서
-- 유저 단위(121번) 결과와 비교 - 상승 결론이 집계 단위에 따라 바뀌는지 확인.

WITH checkout_events AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    event_timestamp
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'begin_checkout'
),
purchase_events AS (
  SELECT
    user_pseudo_id,
    event_timestamp
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),
labeled AS (
  SELECT
    ce.user_pseudo_id,
    ce.event_timestamp,
    CASE
      WHEN ce.event_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간'
      WHEN ce.event_date BETWEEN '2020-11-23' AND '2020-11-30' THEN '블프구간'
      WHEN ce.event_date < '2020-12-14' THEN '평상시'
      ELSE '사후구간'
    END AS period,
    EXISTS (
      SELECT 1 FROM purchase_events p
      WHERE p.user_pseudo_id = ce.user_pseudo_id AND p.event_timestamp >= ce.event_timestamp
    ) AS did_purchase_after
  FROM checkout_events ce
)
SELECT
  period,
  COUNT(*) AS checkout_events,
  SUM(CASE WHEN did_purchase_after THEN 1 ELSE 0 END) AS purchase_after,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN did_purchase_after THEN 1 ELSE 0 END), COUNT(*)) * 100, 2) AS event_level_rate
FROM labeled
GROUP BY period
ORDER BY period
