-- 목적: device.operating_system = 'Web'의 정체 확인 ③ - 주간 시계열로 'Web' 비중이 시기에 따라 바뀌는지 본다.
-- transaction_id처럼 특정 시점에 기록 방식이 바뀐 흔적이 있는지 확인하기 위함.

SELECT
  DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week_start,
  COUNT(*) AS events,
  ROUND(COUNTIF(device.operating_system = 'Web') * 100 / COUNT(*), 2) AS web_pct_all,
  ROUND(SAFE_DIVIDE(COUNTIF(device.operating_system = 'Web' AND device.category = 'desktop'), COUNTIF(device.category = 'desktop')) * 100, 2) AS web_pct_in_desktop,
  ROUND(SAFE_DIVIDE(COUNTIF(device.operating_system = 'Web' AND device.category = 'mobile'), COUNTIF(device.category = 'mobile')) * 100, 2) AS web_pct_in_mobile,
  ROUND(SAFE_DIVIDE(COUNTIF(device.operating_system = 'Web' AND device.category = 'tablet'), COUNTIF(device.category = 'tablet')) * 100, 2) AS web_pct_in_tablet
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY week_start
ORDER BY week_start
