-- 목적: data_quality_tracking 차트용. 주별 begin_checkout 이벤트 중 상품 정보(items>=1개)가
-- 있는 이벤트의 비율을 관측기간 전체(11/1~1/31)에 대해 계산. sql/175(11월 일별)를 전체 기간,
-- 주 단위로 확장한 버전 - 11/23~11/30 전환 구간과 그 이후 안정화를 한 차트에서 보기 위함.
SELECT
  DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week_start,
  COUNT(*) AS checkout_events,
  SUM(CASE WHEN ARRAY_LENGTH(items) > 0 THEN 1 ELSE 0 END) AS events_with_items,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN ARRAY_LENGTH(items) > 0 THEN 1 ELSE 0 END), COUNT(*)) * 100, 2) AS pct_with_items
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'begin_checkout'
GROUP BY week_start
ORDER BY week_start
