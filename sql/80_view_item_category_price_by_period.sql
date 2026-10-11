-- 목적: 1-A단계 - "판매하는 상품"(노출 상품) 구성/가격이 하락구간에 변화했는지 확인.
-- add_to_cart 기준(76번)과 비교하기 위해 동일한 방식(아이템 단위 가중평균)으로,
-- view_item 이벤트 기준 전체 방문자의 상품 노출 구성을 평상시 vs 하락구간으로 비교한다.
-- view_item은 카트 코호트가 아니라 전체 브라우징 활동이라 유저당 첫 이벤트로 제한하지 않고 전체 이벤트를 센다.

WITH view_item_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'view_item'
),
labeled AS (
  SELECT
    CASE WHEN event_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '평상시' END AS period,
    item.item_category AS category,
    item.price AS price
  FROM view_item_events, UNNEST(items) AS item
)
SELECT
  period,
  category,
  COUNT(*) AS item_views,
  ROUND(AVG(price), 2) AS avg_price,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY period), 2) AS pct_of_period_item_views
FROM labeled
GROUP BY period, category
ORDER BY period, item_views DESC
