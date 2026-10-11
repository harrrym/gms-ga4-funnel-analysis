-- 목적: 기프트카드 페이지로 들어오기 직전 페이지 - 같은 세션의 직전 page_view 경로(prev_path)와 이벤트의 page_referrer. 11/1~1/31.
-- prev_path가 NULL이면 세션의 첫 page_view(랜딩)이다. cur_type: list = 기프트카드 목록 경로, detail = 기프트카드 상세(.axd 등).
WITH pv AS (
  SELECT user_pseudo_id, (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sid, PARSE_DATE('%Y%m%d', event_date) AS d, event_timestamp AS ts, LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path,
    LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_referrer'), r'^https?://([^?#]*)')) AS ref
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131' AND event_name = 'page_view'
),
l AS (
  SELECT *, LAG(path) OVER (PARTITION BY user_pseudo_id, sid ORDER BY ts) AS prev_path
  FROM pv WHERE sid IS NOT NULL
)
SELECT d, IF(REGEXP_CONTAINS(path, r'gift[ +]?cards?/'), 'detail', 'list') AS cur_type, prev_path, ref, COUNT(*) AS n
FROM l WHERE REGEXP_CONTAINS(IFNULL(path, ''), r'gift[ +]?cards?')
GROUP BY d, cur_type, prev_path, ref
