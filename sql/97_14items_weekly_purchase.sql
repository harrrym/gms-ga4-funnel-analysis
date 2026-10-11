-- 목적: 품절 의심 14개 상품의 구매가 정확히 몇 주차부터 0이 됐는지 확인 (동시 발생 여부 검증).

WITH target_items AS (
  SELECT item_name FROM UNNEST([
    'Google Leather Strap Hat Blue', 'Google Decal', 'Google Thermal Tumbler Navy',
    'Google Sunnyvale Campus Mug', 'Google Small Standard Journal Navy', 'Google Leather Strap Hat Black',
    'Google Infant Charcoal Onesie', 'Google Confetti Slim Task Pad', 'Google Cork Base Tumbler',
    'Google Youth FC Longsleeve Charcoal', 'Google Youth Badge Tee Navy', 'Google Super G Tumbler (Blue Lid)',
    'Android Large Trace Journal Black', 'YouTube Transmission Journal Red'
  ]) AS item_name
)
SELECT
  item.item_name AS item_name,
  DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week_start,
  COUNT(*) AS purchases
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'purchase'
  AND item.item_name IN (SELECT item_name FROM target_items)
GROUP BY item_name, week_start
ORDER BY item_name, week_start
