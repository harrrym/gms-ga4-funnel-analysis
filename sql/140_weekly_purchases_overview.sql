-- 목적: 11월~1월 전체 주별 구매 건수/구매 유저 수를 뽑아서 블프 당겨구매 가설 확인용 기초 데이터로 쓴다.
SELECT
  DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week_start,
  COUNT(*) AS purchase_events,
  COUNT(DISTINCT user_pseudo_id) AS purchasing_users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'purchase'
GROUP BY week_start
ORDER BY week_start
