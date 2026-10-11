-- 목적: purchase 이벤트의 item_category가 add_to_cart처럼 세분화돼있는지, begin_checkout처럼 뭉뚱그려져 있는지 확인.
SELECT
  item.item_category AS category,
  COUNT(*) AS n
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'purchase'
GROUP BY category
ORDER BY n DESC
