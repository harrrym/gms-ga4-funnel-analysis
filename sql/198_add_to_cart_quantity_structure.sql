-- 목적: add_to_cart 이벤트의 items 중 "실제 담은 상품" 후보(quantity>0) 구조 확인 (12/1~1/11).
-- 이벤트당 quantity>0 아이템 수 분포와, quantity>0 아이템이 배열의 몇 번째에 있는지.
WITH e AS (
  SELECT
    ARRAY_LENGTH(items) AS n_items,
    (SELECT COUNT(1) FROM UNNEST(items) i WHERE i.quantity IS NOT NULL AND i.quantity > 0) AS n_qty,
    (SELECT ARRAY_AGG(off ORDER BY off LIMIT 1)[SAFE_OFFSET(0)] FROM UNNEST(items) i WITH OFFSET off WHERE i.quantity IS NOT NULL AND i.quantity > 0) AS first_qty_pos
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210111' AND event_name = 'add_to_cart'
)
SELECT
  CASE WHEN n_items >= 6 THEN '6개 이상' ELSE '5개 이하' END AS size_group,
  n_qty, COUNT(*) AS events,
  ROUND(AVG(first_qty_pos), 1) AS avg_first_qty_pos,
  APPROX_QUANTILES(first_qty_pos, 4) AS pos_quartiles
FROM e GROUP BY size_group, n_qty ORDER BY size_group, n_qty
