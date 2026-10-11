-- 목적: 데이터 품질 점검 ① - 분석에 쓴 핵심 필드의 NULL/빈값/자리표시자 비율을 전체 이벤트 기준으로 확인한다.
-- 자리표시자: GA4 공개 샘플이 난독화 과정에서 쓰는 '<Other>', '(not set)', '(data deleted)'.

WITH e AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    device.category AS device_category,
    device.operating_system AS operating_system,
    geo.country AS country,
    traffic_source.source AS source,
    traffic_source.medium AS medium,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
)
SELECT
  f.field,
  COUNT(*) AS total_events,
  COUNTIF(f.val IS NULL) AS null_cnt,
  COUNTIF(f.val = '') AS empty_cnt,
  COUNTIF(f.val IN ('(not set)', '<Other>', '(data deleted)')) AS placeholder_cnt,
  ROUND(COUNTIF(f.val IS NULL OR f.val = '' OR f.val IN ('(not set)', '<Other>', '(data deleted)')) * 100 / COUNT(*), 3) AS missing_pct
FROM e, UNNEST([
  STRUCT('user_pseudo_id' AS field, user_pseudo_id AS val),
  STRUCT('event_timestamp', CAST(event_timestamp AS STRING)),
  STRUCT('ga_session_id', CAST(session_id AS STRING)),
  STRUCT('ga_session_number', CAST(session_number AS STRING)),
  STRUCT('device.category', device_category),
  STRUCT('device.operating_system', operating_system),
  STRUCT('geo.country', country),
  STRUCT('traffic_source.source', source),
  STRUCT('traffic_source.medium', medium)
]) AS f
GROUP BY f.field
ORDER BY missing_pct DESC
