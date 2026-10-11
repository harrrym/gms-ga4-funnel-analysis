-- 목적: 목록 노출->담기 1월 말 하락이 데이터 문제인지 확인. 주별 add_to_cart 이벤트 중 상품 정보(items>=1)가 있는 비율 (sql/179의 add_to_cart 버전).
SELECT
  DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week_start,
  COUNT(*) AS cart_events,
  SUM(CASE WHEN ARRAY_LENGTH(items) > 0 THEN 1 ELSE 0 END) AS events_with_items,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN ARRAY_LENGTH(items) > 0 THEN 1 ELSE 0 END), COUNT(*)) * 100, 2) AS pct_with_items,
  AVG(ARRAY_LENGTH(items)) AS avg_items_per_event
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131' AND event_name = 'add_to_cart'
GROUP BY week_start ORDER BY week_start
