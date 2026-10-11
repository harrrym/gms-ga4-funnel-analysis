-- 목적: H2(품절 추정)/H3(신상품) 검증용 - 상품명(소문자) 기준 일별 구매 수량과 최초 노출일. 11/1~1/31.
-- 구매 이벤트의 item_id는 숫자 코드이고 목록 노출 이벤트의 item_id는 GGOE... 코드라 서로 달라서 상품명으로 연결한다.
SELECT 'purchase' AS kind, LOWER(TRIM(item.item_name)) AS name, PARSE_DATE('%Y%m%d', event_date) AS d, SUM(item.quantity) AS n
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131' AND event_name = 'purchase' AND item.item_name IS NOT NULL
GROUP BY name, d
UNION ALL
SELECT 'first_seen', LOWER(TRIM(item.item_name)), MIN(PARSE_DATE('%Y%m%d', event_date)), COUNT(*)
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131' AND event_name IN ('view_item', 'add_to_cart', 'purchase') AND item.item_name IS NOT NULL
GROUP BY LOWER(TRIM(item.item_name))
