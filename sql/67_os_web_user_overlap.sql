-- 목적: device.operating_system = 'Web'의 정체 확인 ④ - 같은 유저(user_pseudo_id)가 'Web'과 다른 OS 값을 오가는지 본다.
-- 같은 유저가 둘을 오간다면 'Web'은 유저의 속성이 아니라 이벤트/스트림 단위의 기록 방식일 가능성이 높다.

WITH u AS (
  SELECT
    user_pseudo_id,
    COUNTIF(device.operating_system = 'Web') AS web_events,
    COUNTIF(device.operating_system != 'Web') AS non_web_events
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  GROUP BY user_pseudo_id
)
SELECT
  CASE
    WHEN web_events > 0 AND non_web_events = 0 THEN 'Web만'
    WHEN web_events = 0 AND non_web_events > 0 THEN '다른 OS만'
    ELSE '둘 다(같은 유저가 오감)'
  END AS user_type,
  COUNT(*) AS users,
  ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2) AS pct_users
FROM u
GROUP BY user_type
ORDER BY users DESC
