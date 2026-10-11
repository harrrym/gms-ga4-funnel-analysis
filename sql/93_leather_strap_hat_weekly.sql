-- 목적: Leather Strap Hat(Black/Blue) 구매가 정확히 언제부터 끊겼는지 주 단위로 확인.
-- 블프 직후부터 끊겼는지, 하락구간(12/14) 즈음에야 끊겼는지 구분.

SELECT
  DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week_start,
  item.item_name AS item_name,
  COUNT(*) AS purchases
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'purchase'
  AND item.item_name IN ('Google Leather Strap Hat Black', 'Google Leather Strap Hat Blue')
GROUP BY week_start, item_name
ORDER BY item_name, week_start
