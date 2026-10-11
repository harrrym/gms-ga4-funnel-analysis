-- 목적: docs/07 "단계별 가중평균 단가" 표(노출/담김/결제시작, 단순 행 평균 방식 - 109번에서 확인된 방법론)를
-- 블랙프라이데이 주(11/23~11/30) 제외 기준으로 재계산.

WITH events AS (
  SELECT
    event_name,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart', 'begin_checkout')
)
SELECT
  event_name,
  CASE
    WHEN event_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간'
    WHEN event_date BETWEEN '2020-11-23' AND '2020-11-30' THEN '블프구간'
    ELSE '평상시(블프제외)'
  END AS period,
  COUNT(*) AS row_count,
  ROUND(AVG(item.price), 2) AS avg_price
FROM events, UNNEST(items) AS item
GROUP BY event_name, period
ORDER BY event_name, period
