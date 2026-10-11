-- 목적: 138번에서 고른 13개 상품의 일별 구매 건수(전체 관측기간) - 대조군 윈도우 비교용.
WITH qualifying_items AS (
  SELECT item.item_name AS item_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20201115'
    AND event_name = 'purchase'
    AND item.item_name IS NOT NULL
  GROUP BY item_name
  HAVING COUNT(*) >= 20
)
SELECT
  item.item_name AS item_name,
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  COUNT(*) AS purchases
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'purchase'
  AND item.item_name IN (SELECT item_name FROM qualifying_items)
GROUP BY item_name, event_date
ORDER BY item_name, event_date
