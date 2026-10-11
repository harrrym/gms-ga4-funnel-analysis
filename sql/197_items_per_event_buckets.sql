-- 목적: view_item/select_item/add_to_cart/begin_checkout/purchase 이벤트당 아이템 수 분포 (12/1~1/11).
SELECT
  event_name,
  CASE WHEN ARRAY_LENGTH(items) = 0 THEN '0개' WHEN ARRAY_LENGTH(items) = 1 THEN '1개' WHEN ARRAY_LENGTH(items) BETWEEN 2 AND 5 THEN '2~5개'
       WHEN ARRAY_LENGTH(items) BETWEEN 6 AND 10 THEN '6~10개' ELSE '11개 이상' END AS bucket,
  COUNT(*) AS events,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY event_name), 1) AS pct
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210111'
  AND event_name IN ('view_item', 'select_item', 'add_to_cart', 'begin_checkout', 'purchase')
GROUP BY event_name, bucket ORDER BY event_name, bucket
