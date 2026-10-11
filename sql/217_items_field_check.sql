-- 목적: H2/H3(품절·노출 구성) 검증용 상품 필드 확인 - 목록 경로 view_item의 아이템에서 item_id 수, 가격 변동 여부, 카테고리 필드 채움.
WITH x AS (
  SELECT item.item_id, item.item_name, item.price, item.price_in_usd, item.item_category, item.item_category2, item.item_brand, item.coupon
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131' AND event_name = 'view_item' AND ARRAY_LENGTH(items) >= 6
),
per_item AS (
  SELECT item_id, COUNT(*) AS impressions, COUNT(DISTINCT price) AS n_prices, MIN(price) AS min_price, MAX(price) AS max_price, COUNT(DISTINCT item_category) AS n_cats
  FROM x GROUP BY item_id
)
SELECT
  COUNT(*) AS n_items, SUM(impressions) AS impressions,
  COUNTIF(n_prices > 1) AS items_with_price_change,
  COUNTIF(max_price > min_price * 1.05) AS items_price_diff_gt5pct,
  COUNTIF(n_cats > 1) AS items_multi_category,
  (SELECT COUNTIF(item_category2 IS NOT NULL AND item_category2 != '(not set)') / COUNT(*) FROM x) AS pct_cat2,
  (SELECT COUNTIF(coupon IS NOT NULL AND coupon != '(not set)') / COUNT(*) FROM x) AS pct_coupon,
  (SELECT COUNTIF(price_in_usd IS NOT NULL) / COUNT(*) FROM x) AS pct_price_usd
FROM per_item
