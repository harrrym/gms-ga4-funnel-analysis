-- 목적: 전처리 점검 - 범주형 필드의 실제 값 목록(상위 25개)을 눈으로 확인한다.
-- 요약 쿼리(57번)가 잡아내지 못하는 "표기는 다르지만 사실상 같은 값"(예: (none) vs (not set))을 사람이 보고 판단하기 위함.

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
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY field ORDER BY n DESC) AS rn
  FROM vals
)
SELECT field, rn, val, n
FROM ranked
WHERE rn <= 25
ORDER BY field, rn
