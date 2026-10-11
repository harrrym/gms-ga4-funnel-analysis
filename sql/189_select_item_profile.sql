-- 목적: select_item(상품 클릭 후보)의 성격 확인 - 이벤트당 아이템 수, 세션 내 add_to_cart와의 관계 (12/1~1/11, 세션 단위).
WITH ev AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    event_name, event_timestamp, ARRAY_LENGTH(items) AS n_items,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sid
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210111'
    AND event_name IN ('select_item', 'add_to_cart', 'view_item')
),
s AS (
  SELECT session_key,
    LOGICAL_OR(event_name = 'select_item') AS has_select,
    LOGICAL_OR(event_name = 'add_to_cart') AS has_cart,
    LOGICAL_OR(event_name = 'view_item') AS has_view,
    MIN(IF(event_name = 'select_item', event_timestamp, NULL)) AS first_select,
    MIN(IF(event_name = 'add_to_cart', event_timestamp, NULL)) AS first_cart
  FROM ev WHERE sid IS NOT NULL GROUP BY session_key
)
SELECT
  COUNTIF(has_cart) AS cart_sessions,
  COUNTIF(has_cart AND has_select) AS cart_sessions_with_select,
  COUNTIF(has_cart AND has_select AND first_select <= first_cart) AS cart_sessions_select_before_cart,
  COUNTIF(has_cart AND has_view) AS cart_sessions_with_view_item,
  COUNTIF(has_select) AS select_sessions,
  COUNTIF(has_select AND has_cart) AS select_sessions_with_cart,
  (SELECT COUNTIF(n_items = 1) / COUNT(*) FROM ev WHERE event_name = 'select_item') AS select_single_item_share
FROM s
