-- 목적: 담김 가중평균 단가(첫 add_to_cart 기준)를 평상시 정의 v3로 재계산.
WITH first_cart_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_cart_date,
    items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp ASC) = 1
)
SELECT
  CASE
    WHEN first_cart_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간'
    WHEN first_cart_date BETWEEN '2020-12-01' AND '2020-12-13' THEN '평상시'
    ELSE '사후구간'
  END AS period,
  COUNT(*) AS row_count,
  ROUND(AVG(item.price), 2) AS avg_price
FROM first_cart_event, UNNEST(items) AS item
GROUP BY period
