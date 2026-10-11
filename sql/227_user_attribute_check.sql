-- 목적: 데이터셋에 성별·연령 등 사용자 속성이 있는지 스키마와 실제 값으로 확인.
SELECT
  COUNT(*) AS events,
  COUNT(DISTINCT user_pseudo_id) AS users,
  COUNTIF(user_id IS NOT NULL) AS user_id_non_null,
  COUNTIF(ARRAY_LENGTH(user_properties) > 0) AS user_properties_non_empty,
  COUNTIF(user_ltv.revenue IS NOT NULL) AS user_ltv_non_null,
  COUNTIF(device.language IS NOT NULL) AS device_language_non_null,
  COUNTIF(geo.country IS NOT NULL AND geo.country != '') AS geo_country_non_empty,
  COUNTIF(geo.city IS NOT NULL AND geo.city NOT IN ('', '(not set)')) AS geo_city_real
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
