-- 목적: view_item 이벤트 1건에 담긴 아이템 수 분포 (상세 페이지면 대부분 1개, 목록 페이지면 여러 개). 12/1~1/11.
SELECT
  CASE WHEN ARRAY_LENGTH(items) = 1 THEN '1개' WHEN ARRAY_LENGTH(items) BETWEEN 2 AND 5 THEN '2~5개' ELSE '6개 이상' END AS items_per_event,
  COUNT(*) AS events,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210111' AND event_name = 'view_item'
GROUP BY items_per_event ORDER BY events DESC
