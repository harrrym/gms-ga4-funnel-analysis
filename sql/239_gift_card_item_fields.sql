-- 목적: 기프트카드 상품의 이름·variant·카테고리 등에 전자(e-gift, digital, email) 단서가 있는지 - 이벤트 종류별 상품 필드 값 분포. 11/1~1/31.
-- 대상 = 상품명 또는 카테고리에 'gift'가 들어간 상품.
SELECT event_name, item.item_id, item.item_name, item.item_brand, item.item_variant, item.item_category, item.item_category2, item.item_category3,
  item.item_list_name, item.coupon, COUNT(*) AS n, MIN(item.price) AS min_price, MAX(item.price) AS max_price
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND (LOWER(item.item_name) LIKE '%gift%' OR LOWER(IFNULL(item.item_category, '')) LIKE '%gift%' OR LOWER(IFNULL(item.item_category2, '')) LIKE '%gift%')
GROUP BY event_name, item.item_id, item.item_name, item.item_brand, item.item_variant, item.item_category, item.item_category2, item.item_category3, item.item_list_name, item.coupon
ORDER BY n DESC
