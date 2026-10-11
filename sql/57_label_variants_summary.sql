-- 목적: 전처리 점검 - 분석에 쓰는 범주형 필드에서 대소문자/공백 때문에 같은 값이 여러 표기로 갈라져 있는지 확인한다.
-- distinct_raw(원본 고유값 수)와 distinct_normalized(LOWER+TRIM 후 고유값 수)가 다르면 표기 불일치가 있다는 뜻이다.

WITH e AS (
  SELECT
    traffic_source.source AS source,
    traffic_source.medium AS medium,
    device.operating_system AS operating_system,
    device.category AS device_category,
    geo.country AS country,
    geo.continent AS continent
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
vals AS (
  SELECT f.field, f.val, COUNT(*) AS n
  FROM e, UNNEST([
    STRUCT('traffic_source.source' AS field, source AS val),
    STRUCT('traffic_source.medium', medium),
    STRUCT('device.operating_system', operating_system),
    STRUCT('device.category', device_category),
    STRUCT('geo.country', country),
    STRUCT('geo.continent', continent)
  ]) AS f
  GROUP BY f.field, f.val
)
SELECT
  field,
  COUNT(*) AS distinct_raw,
  COUNT(DISTINCT LOWER(TRIM(val))) AS distinct_normalized,
  COUNT(*) - COUNT(DISTINCT LOWER(TRIM(val))) AS merged_by_normalizing,
  COUNTIF(val IS NULL) AS null_values,
  COUNTIF(val = '') AS empty_values,
  COUNTIF(val != TRIM(val)) AS values_with_edge_whitespace
FROM vals
GROUP BY field
ORDER BY field
