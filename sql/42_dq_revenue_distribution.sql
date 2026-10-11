-- 목적: 데이터 품질 점검 ③ - purchase 이벤트의 revenue 값 자체가 정상인지 확인한다.
-- NULL/0/음수(환불 가능성)와 상위 이상치(대량 주문)가 ARPPU/AOV/임팩트 추정을 왜곡하는지 보기 위함.

WITH p AS (
  SELECT ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
)
SELECT
  COUNT(*) AS purchase_events,
  COUNTIF(revenue IS NULL) AS rev_null,
  COUNTIF(revenue = 0) AS rev_zero,
  COUNTIF(revenue < 0) AS rev_negative,
  ROUND(MIN(revenue), 2) AS rev_min,
  ROUND(APPROX_QUANTILES(revenue, 100)[OFFSET(25)], 2) AS p25,
  ROUND(APPROX_QUANTILES(revenue, 100)[OFFSET(50)], 2) AS p50,
  ROUND(APPROX_QUANTILES(revenue, 100)[OFFSET(75)], 2) AS p75,
  ROUND(APPROX_QUANTILES(revenue, 100)[OFFSET(90)], 2) AS p90,
  ROUND(APPROX_QUANTILES(revenue, 100)[OFFSET(99)], 2) AS p99,
  ROUND(MAX(revenue), 2) AS rev_max,
  ROUND(AVG(revenue), 2) AS rev_mean,
  ROUND(SUM(revenue), 2) AS rev_sum,
  ROUND(SUM(IF(revenue >= (SELECT APPROX_QUANTILES(revenue, 100)[OFFSET(99)] FROM p), revenue, 0)) * 100 / SUM(revenue), 2) AS top1pct_revenue_share_pct
FROM p
