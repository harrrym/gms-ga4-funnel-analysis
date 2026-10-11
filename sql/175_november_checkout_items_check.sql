-- 목적: 11월 전체 begin_checkout 이벤트 중 상품>=1개인 이벤트가 실제로 있는지 직접 확인
-- (172번 쿼리에서 11월 포함/제외 결과가 왜 동일했는지 검증).
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  COUNT(*) AS checkout_events,
  SUM(CASE WHEN ARRAY_LENGTH(items) > 0 THEN 1 ELSE 0 END) AS events_with_items,
  SUM(ARRAY_LENGTH(items)) AS total_item_rows
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20201130'
  AND event_name = 'begin_checkout'
GROUP BY event_date
ORDER BY event_date
