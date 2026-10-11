-- 목적: 가설(담은 상품 가격대/카테고리 변화) ICE 채점용 가벼운 집계.
-- 하락구간(12/14~1/11) vs 평상시, 첫 add_to_cart 이벤트에 담긴 상품의 카테고리 구성과
-- 평균 단가가 달라졌는지 한 번에 본다. items는 반복 필드라 UNNEST해서 상품 단위로 집계.

WITH first_cart_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_cart_date,
    items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp ASC) = 1
),
labeled AS (
  SELECT
    user_pseudo_id,
    CASE WHEN first_cart_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '평상시' END AS period,
    item.item_category AS category,
    item.price AS price
  FROM first_cart_event, UNNEST(items) AS item
)
SELECT
  period,
  category,
  COUNT(*) AS item_adds,
  COUNT(DISTINCT user_pseudo_id) AS users,
  ROUND(AVG(price), 2) AS avg_price,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY period), 2) AS pct_of_period_item_adds
FROM labeled
GROUP BY period, category
ORDER BY period, item_adds DESC
