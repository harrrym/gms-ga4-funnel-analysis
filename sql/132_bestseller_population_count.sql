-- 목적: 94번(품절 의심 14개 스캔)이 모집단으로 쓴 "평상시 구매 20건 이상" 상품이 총 몇 개인지 확인.
-- 94번과 동일한 선정 기준(event_date < '2020-12-14', 블프 포함)만 쓰고 decline=0 필터는 뺀다.

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
SELECT
  COUNT(*) AS total_qualifying_items,
  SUM(CASE WHEN purchase_decline = 0 THEN 1 ELSE 0 END) AS zero_decline_items,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN purchase_decline = 0 THEN 1 ELSE 0 END), COUNT(*)) * 100, 2) AS zero_decline_pct
FROM agg
WHERE purchase_baseline >= 20
