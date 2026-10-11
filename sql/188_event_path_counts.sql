-- 목적: add_to_cart가 목록/검색/상세 중 어디서 일어나는지 분류하기 위한 경로별 이벤트 수 (12/1~1/11, 쿼리스트링 제거).
SELECT
  event_name,
  REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)') AS path,
  COUNT(*) AS events
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210111'
  AND event_name IN ('page_view', 'view_item', 'select_item', 'add_to_cart')
GROUP BY event_name, path
