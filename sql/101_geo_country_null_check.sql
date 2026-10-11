-- 목적: 3순위 가설(국가/지역) 검증 전, geo.country 필드의 결측/(not set) 비율 확인.
-- 첫 add_to_cart 이벤트 기준, 36번과 동일한 유저 단위 코호트.

WITH first_cart_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_cart_date,
    geo.country AS country
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp ASC) = 1
)
SELECT
  CASE WHEN first_cart_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '평상시' END AS period,
  COUNT(*) AS total_users,
  COUNTIF(country IS NULL) AS null_country,
  COUNTIF(country = '(not set)') AS not_set_country,
  ROUND(SAFE_DIVIDE(COUNTIF(country IS NULL OR country = '(not set)'), COUNT(*)) * 100, 2) AS missing_pct
FROM first_cart_event
GROUP BY period
