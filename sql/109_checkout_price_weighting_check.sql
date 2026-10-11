-- 목적: docs/07의 결제시작 가중평균 단가($19.85/$18.87)가 어떤 가중치 방식으로 나온 값인지 재확인.
-- count 기준(단순 행 평균)과 quantity 기준(수량 가중) 두 가지를 모두 계산해서 어느 쪽이 문서값과 일치하는지 본다.
SELECT
  CASE WHEN PARSE_DATE('%Y%m%d', event_date) BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '평상시' END AS period,
  ROUND(AVG(item.price), 2) AS avg_price_by_count,
  ROUND(SAFE_DIVIDE(SUM(item.price * item.quantity), SUM(item.quantity)), 2) AS avg_price_by_quantity,
  COUNT(*) AS row_count,
  SUM(item.quantity) AS total_quantity
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'begin_checkout'
GROUP BY period
