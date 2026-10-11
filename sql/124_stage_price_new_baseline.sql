-- 목적: docs/07 "단계별 가중평균 단가"(노출/결제시작, 전체 이벤트 단순평균)를 새 평상시 정의로 재계산. 110번과 동일 방법론.

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
    WHEN event_date BETWEEN '2020-11-23' AND '2020-11-30' THEN '블프구간'
    WHEN event_date < '2020-12-14' THEN '평상시'
    ELSE '사후구간'
  END AS period,
  COUNT(*) AS row_count,
  ROUND(AVG(item.price), 2) AS avg_price
FROM events, UNNEST(items) AS item
GROUP BY event_name, period
ORDER BY event_name, period
