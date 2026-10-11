-- 목적: 담김 단가 상승(+7.8%)이 유저 단위로도 유의한지, Hats 제외 시에도 오르는지 검정하기 위한 원본 행.
-- 유저의 첫 add_to_cart 이벤트의 아이템별 (카테고리, 단가). 기간은 v3 정의(평상시 12/1~12/13, 하락구간 12/14~1/11).
-- 유저별 평균/Hats 제외/검정은 notebooks/price_test_v3.py에서 처리 (CATEGORY_MAP 사용).
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
  user_pseudo_id,
  CASE
    WHEN first_cart_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간'
    ELSE '평상시'
  END AS period,
  item.item_category AS raw_category,
  item.price AS price
FROM first_cart_event, UNNEST(items) AS item
WHERE first_cart_date BETWEEN '2020-12-01' AND '2021-01-11'
