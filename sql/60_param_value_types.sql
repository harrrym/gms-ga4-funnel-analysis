-- 목적: 전처리 점검 - 분석에 쓰는 event_params 키가 항상 같은 타입 칸(string/int/float/double)에 들어있는지 확인한다.
-- GA4 event_params는 값 타입별로 칸이 나뉘어 있어서, 같은 키가 어떤 행에선 int_value, 어떤 행에선 string_value에 들어 있으면
-- 우리가 int_value만 읽는 쿼리는 조용히 그 행들을 NULL로 놓친다.
-- 마지막 행은 event_date가 8자리 숫자(YYYYMMDD) 형식이 아닌 행의 수다.

SELECT
  key,
  COUNT(*) AS n,
  COUNTIF(value.string_value IS NOT NULL) AS in_string_value,
  COUNTIF(value.int_value IS NOT NULL) AS in_int_value,
  COUNTIF(value.float_value IS NOT NULL) AS in_float_value,
  COUNTIF(value.double_value IS NOT NULL) AS in_double_value,
  COUNTIF(value.string_value IS NULL AND value.int_value IS NULL AND value.float_value IS NULL AND value.double_value IS NULL) AS in_none
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(event_params)
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND key IN ('ga_session_id', 'ga_session_number', 'transaction_id')
GROUP BY key

UNION ALL

SELECT
  'event_date: 8자리 숫자 형식이 아닌 행 수' AS key,
  COUNTIF(NOT REGEXP_CONTAINS(event_date, r'^[0-9]{8}$')) AS n,
  NULL, NULL, NULL, NULL, NULL
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'

ORDER BY key
