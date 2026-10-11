-- 목적: 단계별 가중평균 단가(노출/결제시작)를 평상시 정의 v3(12/1~12/13)로 재계산.
WITH events AS (
  SELECT
    event_name,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_item', 'begin_checkout')
)
SELECT
  event_name,
  CASE
    WHEN event_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간'
    WHEN event_date BETWEEN '2020-12-01' AND '2020-12-13' THEN '평상시'
    ELSE '사후구간'
  END AS period,
  COUNT(*) AS row_count,
  ROUND(AVG(item.price), 2) AS avg_price
FROM events, UNNEST(items) AS item
GROUP BY event_name, period
ORDER BY event_name, period
