-- 목적: 지역 코호트 분석 전, geo 필드가 얼마나 다양하게/신뢰성 있게 채워져 있는지 먼저 확인.

WITH session_events AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
    geo.country AS country,
    geo.continent AS continent
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
first_touch AS (
  SELECT
    user_pseudo_id,
    ANY_VALUE(country) AS country,
    ANY_VALUE(continent) AS continent
  FROM session_events
  WHERE session_number = 1 AND session_id IS NOT NULL
  GROUP BY user_pseudo_id
)
SELECT
  continent,
  country,
  COUNT(*) AS new_users,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM first_touch
GROUP BY continent, country
ORDER BY new_users DESC
LIMIT 20
