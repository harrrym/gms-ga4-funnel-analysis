-- 목적: revenue=0인 purchase 450건이 무엇인지 확인한다.
-- 상품(items)이 실제로 담긴 주문인데 revenue 필드만 0인지, 아니면 상품 정보도 없는 빈 이벤트인지,
-- 같은 세션에 정상 purchase가 따로 있는지(이중 발화 의심), 결제 단계(begin_checkout/add_payment_info)를 거쳤는지를 본다.

WITH ev AS (
  SELECT
    user_pseudo_id,
    event_name,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sid,
    ecommerce.purchase_revenue_in_usd AS revenue,
    ARRAY_LENGTH(items) AS n_items,
    (SELECT SUM(price_in_usd * quantity) FROM UNNEST(items)) AS items_value
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
zero AS (
  SELECT * FROM ev WHERE event_name = 'purchase' AND revenue = 0
),
pos_sessions AS (
  SELECT DISTINCT user_pseudo_id, sid FROM ev WHERE event_name = 'purchase' AND revenue > 0
),
checkout_sessions AS (
  SELECT DISTINCT user_pseudo_id, sid FROM ev WHERE event_name = 'begin_checkout'
),
payment_sessions AS (
  SELECT DISTINCT user_pseudo_id, sid FROM ev WHERE event_name = 'add_payment_info'
)
SELECT
  COUNT(*) AS zero_revenue_purchases,
  COUNTIF(z.n_items = 0) AS no_items,
  COUNTIF(z.n_items > 0) AS has_items,
  COUNTIF(z.items_value > 0) AS items_value_positive,
  ROUND(SUM(z.items_value), 2) AS items_value_sum,
  COUNTIF(ps.sid IS NOT NULL) AS same_session_has_normal_purchase,
  COUNTIF(cs.sid IS NOT NULL) AS same_session_has_begin_checkout,
  COUNTIF(pay.sid IS NOT NULL) AS same_session_has_add_payment_info
FROM zero z
LEFT JOIN pos_sessions ps ON ps.user_pseudo_id = z.user_pseudo_id AND ps.sid = z.sid
LEFT JOIN checkout_sessions cs ON cs.user_pseudo_id = z.user_pseudo_id AND cs.sid = z.sid
LEFT JOIN payment_sessions pay ON pay.user_pseudo_id = z.user_pseudo_id AND pay.sid = z.sid
