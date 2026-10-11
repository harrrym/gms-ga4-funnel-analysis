-- 목적: 카테고리 유형별 전환율을 평상시 정의 v3(12/1~12/13만)로 재계산. 결제시작은 원래대로.
WITH cart_category_counts AS (
  SELECT
    item.item_name AS item_name,
    item.item_category AS category,
    COUNT(*) AS n
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
    AND item.item_name IS NOT NULL
    AND item.item_category IS NOT NULL
    AND item.item_category != ''
  GROUP BY item.item_name, item.item_category
),
cart_name_to_category AS (
  SELECT
    item_name,
    ARRAY_AGG(category ORDER BY n DESC, category LIMIT 1)[OFFSET(0)] AS category
  FROM cart_category_counts
  GROUP BY item_name
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
cart_items_typed AS (
  SELECT
    fc.user_pseudo_id,
    fc.first_cart_date,
    CASE
      WHEN COALESCE(m.category, item.item_category) IN (
        'Home/Stationery/', 'Home/Stationery/Notebooks/', 'Home/Stationery/Stickers/', 'Home/Stationery/Writing/',
        'Stationery', 'Notebooks', 'Writing', 'Office',
        'Home/Shop by Brand/', 'Home/Shop by Brand/Android/', 'Home/Shop by Brand/Google/',
        'Home/Shop by Brand/YouTube/', 'Home/Shop by Brand/#IamRemarkable/',
        'Shop by Brand', 'Android', 'Google', 'YouTube',
        'Home/Campus Collection/', 'Campus Collection'
      ) THEN '저관여소모품'
      ELSE '그외'
    END AS item_type
  FROM first_cart_event fc, UNNEST(items) AS item
  LEFT JOIN cart_name_to_category m ON m.item_name = item.item_name
),
user_type AS (
  SELECT
    user_pseudo_id,
    first_cart_date,
    CASE WHEN COUNTIF(item_type = '저관여소모품') >= COUNT(*) * 0.5 THEN '저관여형' ELSE '그외형' END AS user_type
  FROM cart_items_typed
  GROUP BY user_pseudo_id, first_cart_date
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
    ut.user_pseudo_id,
    ut.first_cart_date,
    ut.user_type,
    MAX(CASE WHEN e.event_name = 'begin_checkout' AND e.event_date >= ut.first_cart_date THEN 1 ELSE 0 END) AS did_checkout
  FROM user_type ut
  LEFT JOIN events e ON e.user_pseudo_id = ut.user_pseudo_id
  GROUP BY ut.user_pseudo_id, ut.first_cart_date, ut.user_type
),
labeled AS (
  SELECT
    *,
    CASE
      WHEN first_cart_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간'
      WHEN first_cart_date BETWEEN '2020-12-01' AND '2020-12-13' THEN '평상시'
      ELSE '사후구간'
    END AS period
  FROM user_outcome
)
SELECT
  user_type,
  period,
  COUNT(*) AS users,
  SUM(did_checkout) AS checkout_users,
  ROUND(SAFE_DIVIDE(SUM(did_checkout), COUNT(*)) * 100, 2) AS cart_to_checkout_rate
FROM labeled
GROUP BY user_type, period
ORDER BY user_type, period
