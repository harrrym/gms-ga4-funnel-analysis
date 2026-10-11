-- 목적: 배송 마감(12/18)이 빠른 배송 선택에 영향을 줬는지 - 구매의 shipping_tier를 일별로 집계. 11/1~1/31.
-- 구매 = purchase 이벤트를 transaction_id로 묶은 주문(transaction_id가 없으면 이벤트 1건을 1주문으로 셈). 날짜 = 구매 이벤트의 event_date.
-- 분류: ground = 이름에 Ground 포함, intl = International Shipping, express = 그 외 값(2Day, 2nd Day Air, 3 Day Select, Overnight, Next Day Air), tier_null = shipping_tier 없음.
WITH p AS (
  SELECT PARSE_DATE('%Y%m%d', event_date) AS d,
    IFNULL(ecommerce.transaction_id, CONCAT('noid-', CAST(event_timestamp AS STRING), user_pseudo_id)) AS tx,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'shipping_tier') AS tier
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131' AND event_name = 'purchase'
),
o AS (
  SELECT tx, MIN(d) AS d, MAX(TRIM(tier)) AS tier, COUNT(*) AS n_events FROM p GROUP BY tx
)
SELECT d, COUNT(*) AS orders, SUM(n_events) AS purchase_events,
  COUNTIF(tier IS NULL) AS tier_null,
  COUNTIF(tier LIKE '%Ground%') AS ground,
  COUNTIF(tier LIKE 'International%') AS intl,
  COUNTIF(tier IS NOT NULL AND tier NOT LIKE '%Ground%' AND tier NOT LIKE 'International%') AS express,
  COUNTIF(REGEXP_CONTAINS(IFNULL(tier, ''), r'(?i)overnight|next day')) AS next_day,
  COUNTIF(REGEXP_CONTAINS(IFNULL(tier, ''), r'(?i)2day|2nd day')) AS two_day,
  COUNTIF(REGEXP_CONTAINS(IFNULL(tier, ''), r'(?i)3 day')) AS three_day
FROM o GROUP BY d ORDER BY d
