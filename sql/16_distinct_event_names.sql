-- 목적: Activation 아하모먼트 후보를 비교하기 전에, 이 데이터셋에 실제로 어떤 이벤트가 있는지 확인한다.
-- 추측으로 이벤트명을 고르지 않기 위한 사전 점검.

SELECT
  event_name,
  COUNT(*) AS event_count
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY event_name
ORDER BY event_count DESC
