-- 목적: 2순위 가설 정식 검증 - 지연일수 증가가 실제로 유의한지, 그리고 1순위에서 찾은
-- "카테고리 성격(저관여형/그외형)" 차이만으로 상쇄되는 착시는 아닌지 층화해서 확인한다.
-- 78번(지연일수)과 90번(카테고리 유형 분류)을 결합.

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
first_checkout_after AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'begin_checkout'
),
joined AS (
  SELECT
    ut.user_pseudo_id,
    ut.first_cart_date,
    ut.user_type,
    MIN(fca.event_date) AS first_checkout_date
  FROM user_type ut
  JOIN first_checkout_after fca
    ON fca.user_pseudo_id = ut.user_pseudo_id
    AND fca.event_date >= ut.first_cart_date
  GROUP BY ut.user_pseudo_id, ut.first_cart_date, ut.user_type
),
labeled AS (
  SELECT
    *,
    DATE_DIFF(first_checkout_date, first_cart_date, DAY) AS lag_days,
    CASE WHEN first_cart_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '평상시' END AS period
  FROM joined
)
SELECT
  user_type,
  period,
  COUNT(*) AS converted_users,
  ROUND(AVG(lag_days), 2) AS avg_lag_days,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN lag_days = 0 THEN 1 ELSE 0 END), COUNT(*)) * 100, 2) AS pct_same_day,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN lag_days >= 7 THEN 1 ELSE 0 END), COUNT(*)) * 100, 2) AS pct_lag_7d_plus
FROM labeled
GROUP BY user_type, period
ORDER BY user_type, period
