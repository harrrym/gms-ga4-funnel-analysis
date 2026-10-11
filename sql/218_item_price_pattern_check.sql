-- 목적: 상품 가격이 시기별로 어떻게 달라지는지 확인(세일 추정 가능성). 노출 상위 상품 3개의 주별 가격 분포.
WITH x AS (
  SELECT item.item_id, ANY_VALUE(item.item_name) AS item_name, DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS wk, item.price AS price, COUNT(*) AS n
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131' AND event_name = 'view_item' AND ARRAY_LENGTH(items) >= 6
  GROUP BY item.item_id, wk, price
),
top AS (SELECT item_id FROM x GROUP BY item_id ORDER BY SUM(n) DESC LIMIT 3)
SELECT x.item_id, ANY_VALUE(item_name) AS item_name, wk, ARRAY_AGG(STRUCT(price, n) ORDER BY n DESC LIMIT 4) AS top_prices
FROM x JOIN top USING (item_id) GROUP BY item_id, wk ORDER BY item_id, wk
