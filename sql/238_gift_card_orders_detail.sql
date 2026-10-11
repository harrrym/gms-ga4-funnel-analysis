-- 목적: 기프트카드가 들어간 주문 각각의 배송 등급, 구성(기프트카드만/다른 상품과 함께), 같은 세션의 결제 단계 이벤트(add_shipping_info 등). 11/1~1/31.
-- 주문 = purchase 이벤트를 transaction_id로 묶음(첫 이벤트 기준). 기프트카드 = 상품명에 'gift card'가 들어간 상품.
WITH p AS (
  SELECT user_pseudo_id, (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sid, event_timestamp AS ts, PARSE_DATE('%Y%m%d', event_date) AS d,
    ecommerce.transaction_id AS tx, ecommerce.purchase_revenue_in_usd AS revenue,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'shipping_tier') AS tier, items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131' AND event_name = 'purchase'
),
g AS (
  SELECT tx, ARRAY_AGG(STRUCT(user_pseudo_id, sid, ts, d, revenue, tier, items) ORDER BY ts LIMIT 1)[OFFSET(0)] AS r, COUNT(*) AS n_events
  FROM p WHERE EXISTS(SELECT 1 FROM UNNEST(items) i WHERE LOWER(i.item_name) LIKE '%gift card%') GROUP BY tx
),
ses AS (
  SELECT user_pseudo_id, (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sid,
    LOGICAL_OR(event_name = 'begin_checkout') AS has_begin_checkout,
    LOGICAL_OR(event_name = 'add_shipping_info') AS has_add_shipping_info,
    LOGICAL_OR(event_name = 'add_payment_info') AS has_add_payment_info,
    COUNTIF(event_name = 'add_shipping_info') AS n_add_shipping_info
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131' AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
  GROUP BY user_pseudo_id, sid
)
SELECT g.tx, g.r.d AS d, g.r.tier AS tier, g.n_events, g.r.revenue AS revenue_usd,
  ARRAY_LENGTH(g.r.items) AS item_lines,
  (SELECT COUNT(*) FROM UNNEST(g.r.items) i WHERE LOWER(i.item_name) LIKE '%gift card%') AS gift_lines,
  (SELECT STRING_AGG(CONCAT(i.item_name, ' x', CAST(i.quantity AS STRING), ' [variant=', IFNULL(i.item_variant, 'NULL'), ']'), ' | ') FROM UNNEST(g.r.items) i) AS items_desc,
  s.has_begin_checkout, s.has_add_shipping_info, s.n_add_shipping_info, s.has_add_payment_info
FROM g LEFT JOIN ses s ON s.user_pseudo_id = g.r.user_pseudo_id AND s.sid = g.r.sid
ORDER BY d, g.tx
