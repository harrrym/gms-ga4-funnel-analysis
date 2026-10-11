-- 목적: 하락구간 cart 코호트에서 "품절 이후 상태인 상품을 1개 이상 담은 유저"를 분리해서
-- 이들의 전환율과, 이들을 뺐을 때 전체 하락구간 전환율이 얼마나 회복되는지 확인.

WITH stockout_start AS (
  SELECT * FROM UNNEST([
    STRUCT('Google Leather Strap Hat Black' AS item_name, DATE('2020-11-30') AS start_date),
    ('Google Small Standard Journal Navy', DATE('2020-11-30')),
    ('Google Super G Tumbler (Blue Lid)', DATE('2020-12-07')),
    ('Google Infant Charcoal Onesie', DATE('2020-12-07')),
    ('Android Large Trace Journal Black', DATE('2020-12-07')),
    ('Google Leather Strap Hat Blue', DATE('2020-12-14')),
    ('Google Decal', DATE('2020-12-14')),
    ('Google Sunnyvale Campus Mug', DATE('2020-12-14')),
    ('YouTube Transmission Journal Red', DATE('2020-12-14')),
    ('Google Thermal Tumbler Navy', DATE('2020-12-14')),
    ('Google Cork Base Tumbler', DATE('2020-12-14')),
    ('Google Confetti Slim Task Pad', DATE('2020-12-14')),
    ('Google Youth FC Longsleeve Charcoal', DATE('2020-12-14')),
    ('Google Youth Badge Tee Navy', DATE('2020-12-14'))
  ])
),
first_cart_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_cart_date,
    items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp ASC) = 1
),
decline_cohort AS (
  SELECT
    user_pseudo_id,
    first_cart_date,
    items
  FROM first_cart_event
  WHERE first_cart_date BETWEEN '2020-12-14' AND '2021-01-11'
),
user_flag AS (
  SELECT
    dc.user_pseudo_id,
    dc.first_cart_date,
    MAX(CASE WHEN s.start_date IS NOT NULL AND dc.first_cart_date >= s.start_date THEN 1 ELSE 0 END) AS has_poststockout_item
  FROM decline_cohort dc, UNNEST(dc.items) AS item
  LEFT JOIN stockout_start s ON s.item_name = item.item_name
  GROUP BY dc.user_pseudo_id, dc.first_cart_date
),
events AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
user_outcome AS (
  SELECT
    uf.user_pseudo_id,
    uf.has_poststockout_item,
    MAX(CASE WHEN e.event_name = 'begin_checkout' AND e.event_date >= uf.first_cart_date THEN 1 ELSE 0 END) AS did_checkout
  FROM user_flag uf
  LEFT JOIN events e ON e.user_pseudo_id = uf.user_pseudo_id
  GROUP BY uf.user_pseudo_id, uf.has_poststockout_item
)
SELECT
  has_poststockout_item,
  COUNT(*) AS users,
  SUM(did_checkout) AS checkout_users,
  ROUND(SAFE_DIVIDE(SUM(did_checkout), COUNT(*)) * 100, 2) AS cart_to_checkout_rate
FROM user_outcome
GROUP BY has_poststockout_item
ORDER BY has_poststockout_item
