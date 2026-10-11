-- 목적: device.operating_system = 'Web'의 정체 확인 ① - 기기 종류(category)와 OS의 교차 분포.
-- "Web"이 desktop/mobile/tablet 중 어디에 걸쳐 있는지, 다른 OS 값들과 어떻게 갈리는지 본다.

SELECT
  device.category AS device_category,
  device.operating_system AS operating_system,
  COUNT(*) AS events,
  COUNT(DISTINCT user_pseudo_id) AS users,
  ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (PARTITION BY device.category), 2) AS pct_within_category
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY device_category, operating_system
ORDER BY device_category, events DESC
