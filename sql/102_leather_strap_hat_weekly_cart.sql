-- 목적: Leather Strap Hat(Black/Blue)의 담기(add_to_cart)가 주 단위로 계속 유지됐는지 확인.
-- sql/93(구매 주간)과 짝을 이뤄 "담기는 유지되는데 구매만 0" 시각화에 사용.

SELECT
  DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week_start,
  item.item_name AS item_name,
  COUNT(*) AS cart_adds
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'add_to_cart'
  AND item.item_name IN ('Google Leather Strap Hat Black', 'Google Leather Strap Hat Blue')
GROUP BY week_start, item_name
ORDER BY item_name, week_start
