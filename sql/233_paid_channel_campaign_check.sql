-- 목적: 리타게팅(재마케팅) 광고를 집행하는지 간접 확인 - 유료 매체(cpc, cpm, display 등)의 소스·캠페인 이름 값과 세션 수. 11/1~1/31.
-- 두 곳을 본다: (1) traffic_source(유저 첫 유입, GA4 내보내기 기준) (2) session_start 이벤트의 source/medium/campaign 파라미터(세션 단위).
SELECT 'user_first_touch' AS src, traffic_source.source AS source, traffic_source.medium AS medium, traffic_source.name AS campaign,
  COUNT(DISTINCT user_pseudo_id) AS users, COUNT(*) AS events
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY source, medium, campaign
UNION ALL
SELECT 'session_start_params',
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'source'),
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'medium'),
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'campaign'),
  COUNT(DISTINCT user_pseudo_id), COUNT(*)
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131' AND event_name = 'session_start'
GROUP BY 2, 3, 4
