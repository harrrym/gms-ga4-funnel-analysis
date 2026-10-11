-- 목적: 2단계 - "결제시작한 상품"의 카테고리/가격 구성이 하락구간에 달라졌는지 확인.
-- begin_checkout 이벤트 자체의 items(그 순간 카트 스냅샷, remove_from_cart 문제에서 자유로움)를 사용.
-- 76번(add_to_cart 기준)과 동일한 방식으로 아이템 단위 집계.

WITH begin_checkout_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'begin_checkout'
),
labeled AS (
  SELECT
    CASE WHEN event_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '평상시' END AS period,
    item.item_category AS category,
    item.price AS price
  FROM begin_checkout_events, UNNEST(items) AS item
)
SELECT
  period,
  category,
  COUNT(*) AS item_count,
  ROUND(AVG(price), 2) AS avg_price,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY period), 2) AS pct_of_period_items
FROM labeled
GROUP BY period, category
ORDER BY period, item_count DESC
