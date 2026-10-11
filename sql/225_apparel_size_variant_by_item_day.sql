-- 목적: 사이즈 품절(H2 보완) 확인 - purchase/begin_checkout 아이템의 (날짜, 상품명, item_variant)별 수량. 12/1~1/31.
-- add_to_cart·view_item은 item_variant 채움 비율이 낮아(5%, 0.6%) 사이즈 분포를 못 보고, purchase(96%)와 begin_checkout(97%)만 사용.
SELECT event_name AS kind, PARSE_DATE('%Y%m%d', event_date) AS d, LOWER(TRIM(item.item_name)) AS item_name, UPPER(TRIM(item.item_variant)) AS variant,
  SUM(item.quantity) AS units, COUNT(*) AS item_rows
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131' AND event_name IN ('purchase', 'begin_checkout')
  AND REGEXP_CONTAINS(UPPER(TRIM(item.item_variant)), r'^(XXS|XS|SM|MD|LG|XL|2XL|3XL)$')
GROUP BY kind, d, item_name, variant
