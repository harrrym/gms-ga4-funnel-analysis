-- 목적: 블프구간(11/23~11/30, 8일) 구매량이 평상시(하락 이전, 블프 제외) 주 평균 대비 얼마나 높은지 확인.
-- 정확한 날짜 경계 사용(주 단위 반올림 없이).
SELECT
  CASE
    WHEN PARSE_DATE('%Y%m%d', event_date) BETWEEN '2020-11-23' AND '2020-11-30' THEN '블프구간'
    WHEN PARSE_DATE('%Y%m%d', event_date) < '2020-12-14' THEN '평상시'
    ELSE '기타'
  END AS period,
  COUNT(*) AS purchase_events,
  COUNT(DISTINCT user_pseudo_id) AS purchasing_users,
  COUNT(DISTINCT event_date) AS n_days
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'purchase'
GROUP BY period
