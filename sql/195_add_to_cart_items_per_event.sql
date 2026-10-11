-- 목적: add_to_cart 이벤트 1건에 담긴 아이템 수 분포 확인 (평균 ~11개로 나와서 담은 상품 1개가 아닐 가능성 점검). 12/1~1/11.
SELECT
  CASE WHEN ARRAY_LENGTH(items) = 1 THEN '1개' WHEN ARRAY_LENGTH(items) BETWEEN 2 AND 5 THEN '2~5개'
       WHEN ARRAY_LENGTH(items) BETWEEN 6 AND 10 THEN '6~10개' ELSE '11개 이상' END AS items_per_event,
  COUNT(*) AS events, ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210111' AND event_name = 'add_to_cart'
GROUP BY items_per_event ORDER BY events DESC
