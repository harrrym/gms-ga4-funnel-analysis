-- 목적: 카테고리 유형별 보기(view_item)->담기(add_to_cart) 유저 단위 전환율 (12월 초 vs 하락구간).
-- 유형 분류는 sql/162(담기->결제시작)와 동일: 아이템 카테고리(담기 이벤트 기준 이름->최빈 카테고리 매핑)가
-- 저관여소모품(문구/브랜드/캠퍼스)인 아이템이 50% 이상이면 저관여형, 아니면 그외형. 단 여기서는 유저의 "첫 view_item"
-- 이벤트의 아이템으로 분류하고, 코호트 날짜도 첫 view_item 날짜. 결과는 첫 view_item 날짜 이후(포함) add_to_cart 여부.
-- did_cart_7d: 첫 view_item 후 7일(당일 포함 7일) 이내 담기 (우측 절단 민감도).
WITH cart_category_counts AS (
  SELECT item.item_name AS item_name, item.item_category AS category, COUNT(*) AS n
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
    AND item.item_name IS NOT NULL AND item.item_category IS NOT NULL AND item.item_category != ''
  GROUP BY item.item_name, item.item_category
),
cart_name_to_category AS (
  SELECT item_name, ARRAY_AGG(category ORDER BY n DESC, category LIMIT 1)[OFFSET(0)] AS category
  FROM cart_category_counts GROUP BY item_name
),
first_view_event AS (
  SELECT user_pseudo_id, PARSE_DATE('%Y%m%d', event_date) AS first_view_date, items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210111'
    AND event_name = 'view_item'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp ASC) = 1
),
view_items_typed AS (
  SELECT
    fv.user_pseudo_id, fv.first_view_date,
    CASE
      WHEN COALESCE(m.category, item.item_category) IN (
        'Home/Stationery/', 'Home/Stationery/Notebooks/', 'Home/Stationery/Stickers/', 'Home/Stationery/Writing/',
        'Stationery', 'Notebooks', 'Writing', 'Office',
        'Home/Shop by Brand/', 'Home/Shop by Brand/Android/', 'Home/Shop by Brand/Google/',
        'Home/Shop by Brand/YouTube/', 'Home/Shop by Brand/#IamRemarkable/',
        'Shop by Brand', 'Android', 'Google', 'YouTube',
        'Home/Campus Collection/', 'Campus Collection'
      ) THEN '저관여소모품' ELSE '그외'
    END AS item_type
  FROM first_view_event fv, UNNEST(items) AS item
  LEFT JOIN cart_name_to_category m ON m.item_name = item.item_name
),
user_type AS (
  SELECT user_pseudo_id, first_view_date,
    CASE WHEN COUNTIF(item_type = '저관여소모품') >= COUNT(*) * 0.5 THEN '저관여형' ELSE '그외형' END AS user_type
  FROM view_items_typed GROUP BY user_pseudo_id, first_view_date
),
cart_events AS (
  SELECT user_pseudo_id, PARSE_DATE('%Y%m%d', event_date) AS cart_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131' AND event_name = 'add_to_cart'
),
outcome AS (
  SELECT
    ut.user_pseudo_id, ut.first_view_date, ut.user_type,
    MAX(IF(c.cart_date >= ut.first_view_date, 1, 0)) AS did_cart,
    MAX(IF(c.cart_date BETWEEN ut.first_view_date AND DATE_ADD(ut.first_view_date, INTERVAL 6 DAY), 1, 0)) AS did_cart_7d
  FROM user_type ut LEFT JOIN cart_events c ON c.user_pseudo_id = ut.user_pseudo_id
  GROUP BY ut.user_pseudo_id, ut.first_view_date, ut.user_type
)
SELECT
  CASE WHEN first_view_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '12월 초' END AS period,
  user_type,
  COUNT(*) AS users, SUM(did_cart) AS cart_users, SUM(did_cart_7d) AS cart_users_7d
FROM outcome
GROUP BY period, user_type
ORDER BY user_type, period
