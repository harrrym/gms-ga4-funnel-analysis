-- 목적: view_item 이벤트가 상품 상세 페이지에서 찍히는지 확인. view_item 이벤트의 page_location 경로 상위 분포.
WITH v AS (
  SELECT
    REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)') AS path
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210111' AND event_name = 'view_item'
)
SELECT path, COUNT(*) AS events, ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM v GROUP BY path ORDER BY events DESC LIMIT 25
