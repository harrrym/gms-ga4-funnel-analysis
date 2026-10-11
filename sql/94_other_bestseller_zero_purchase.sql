-- 목적: Hats 말고 다른 카테고리에서도 "평상시엔 잘 팔렸는데 하락구간엔 구매 0건"인 품절 의심 상품이 있는지 전체 스캔.
-- 평상시 구매 20건 이상(의미있는 베스트셀러)인 상품 중, 하락구간 구매가 0건인 것만 추린다.

WITH purchase_items AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    item.item_name AS item_name,
    item.item_category AS category
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND item.item_name IS NOT NULL
),
agg AS (
  SELECT
    item_name,
    ANY_VALUE(category) AS category,
    COUNTIF(event_date < '2020-12-14') AS purchase_baseline,
    COUNTIF(event_date BETWEEN '2020-12-14' AND '2021-01-11') AS purchase_decline
  FROM purchase_items
  GROUP BY item_name
)
SELECT *
FROM agg
WHERE purchase_baseline >= 20 AND purchase_decline = 0
ORDER BY purchase_baseline DESC
