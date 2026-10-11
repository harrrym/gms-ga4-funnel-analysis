-- 목적: 94/132번의 167개 모집단(평상시 구매 20건 이상) 각각의 일별 구매 건수를 뽑아서,
-- 하락구간이 아닌 다른 29일짜리 구간에서도 "구매 0건" 비율이 비슷한지 비교하는 데 쓴다.

WITH purchase_items AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    item.item_name AS item_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND item.item_name IS NOT NULL
),
baseline_count AS (
  SELECT
    item_name,
    COUNTIF(event_date < '2020-12-14') AS purchase_baseline
  FROM purchase_items
  GROUP BY item_name
  HAVING purchase_baseline >= 20
)
SELECT
  p.item_name,
  p.event_date,
  COUNT(*) AS purchases
FROM purchase_items p
JOIN baseline_count b ON b.item_name = p.item_name
GROUP BY p.item_name, p.event_date
ORDER BY p.item_name, p.event_date
