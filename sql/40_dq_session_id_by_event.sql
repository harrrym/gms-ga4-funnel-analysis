-- 목적: 데이터 품질 점검 ① 보조 - ga_session_id가 비는 이벤트가 어떤 event_name에 몰려있는지 확인한다.
-- 28개 쿼리가 session_id IS NOT NULL로 필터링하는데, 이 필터가 purchase/add_to_cart 같은
-- 핵심 이벤트를 조용히 버리고 있지는 않은지 검증하기 위함.

SELECT
  event_name,
  COUNT(*) AS events,
  COUNTIF((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NULL) AS session_id_null,
  ROUND(COUNTIF((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NULL) * 100 / COUNT(*), 3) AS session_id_null_pct
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY event_name
ORDER BY events DESC
