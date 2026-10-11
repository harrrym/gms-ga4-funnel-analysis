-- 목적: H2 보완(상품 단위) - quantity>0 아이템이 있는 add_to_cart 이벤트의 (세션, 날짜, 경로, 상품명). 12/1~1/31.
-- 이벤트당 quantity>0 아이템은 최대 1개(sql/198)라 그 아이템을 "실제 담은 상품"으로 본다. 상품명은 소문자 기준.
SELECT
  CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS session_key,
  PARSE_DATE('%Y%m%d', event_date) AS d,
  LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path,
  LOWER(TRIM(item.item_name)) AS item_name,
  item.quantity AS quantity
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131'
  AND event_name = 'add_to_cart'
  AND item.quantity IS NOT NULL AND item.quantity > 0
  AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
