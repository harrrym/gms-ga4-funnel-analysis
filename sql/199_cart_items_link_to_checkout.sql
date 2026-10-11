-- 목적: 같은 세션에서 add_to_cart 이후의 첫 begin_checkout/purchase 상품이 그 이전 add_to_cart의 items 안에 들어 있는지, 몇 번째 위치인지 (12/1~1/11).
-- 대상: 세션 안에 첫 결제시작(또는 구매) 이전 add_to_cart가 있는 세션. 매칭 기준 item_id.
WITH ev AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    event_name, event_timestamp, items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210111'
    AND event_name IN ('add_to_cart', 'begin_checkout', 'purchase')
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
),
atc AS (
  SELECT session_key, event_timestamp AS ts, item.item_id, off AS pos, item.quantity AS q
  FROM ev, UNNEST(items) AS item WITH OFFSET off WHERE event_name = 'add_to_cart'
),
target AS (
  SELECT target_event, session_key, ts, items FROM (
    SELECT event_name AS target_event, session_key, event_timestamp AS ts, items,
      ROW_NUMBER() OVER (PARTITION BY session_key, event_name ORDER BY event_timestamp) AS rn
    FROM ev WHERE event_name IN ('begin_checkout', 'purchase') AND ARRAY_LENGTH(items) > 0
  ) WHERE rn = 1
),
t_items AS (
  SELECT target_event, session_key, ts AS target_ts, item.item_id FROM target, UNNEST(items) AS item
),
matched AS (
  SELECT t.target_event, t.session_key, t.item_id,
    COUNT(a.item_id) AS n_match,
    COUNTIF(a.q IS NOT NULL AND a.q > 0) AS n_match_q,
    ARRAY_AGG(a.pos ORDER BY a.ts DESC LIMIT 1)[SAFE_OFFSET(0)] AS last_pos,
    ARRAY_AGG(IF(a.q IS NOT NULL AND a.q > 0, a.pos, NULL) IGNORE NULLS ORDER BY a.ts DESC LIMIT 1)[SAFE_OFFSET(0)] AS last_pos_q
  FROM t_items t LEFT JOIN atc a ON a.session_key = t.session_key AND a.item_id = t.item_id AND a.ts <= t.target_ts
  WHERE EXISTS (SELECT 1 FROM atc x WHERE x.session_key = t.session_key AND x.ts <= t.target_ts)
  GROUP BY t.target_event, t.session_key, t.item_id
)
SELECT
  target_event,
  COUNT(DISTINCT session_key) AS sessions,
  COUNT(*) AS target_items,
  ROUND(100 * COUNTIF(n_match > 0) / COUNT(*), 1) AS pct_in_cart_items,
  ROUND(100 * COUNTIF(n_match_q > 0) / COUNT(*), 1) AS pct_in_cart_items_qty,
  ROUND(AVG(last_pos), 1) AS avg_pos_all,
  APPROX_QUANTILES(last_pos, 4) AS pos_quartiles_all,
  ROUND(AVG(last_pos_q), 1) AS avg_pos_qty,
  APPROX_QUANTILES(last_pos_q, 4) AS pos_quartiles_qty
FROM matched GROUP BY target_event ORDER BY target_event
