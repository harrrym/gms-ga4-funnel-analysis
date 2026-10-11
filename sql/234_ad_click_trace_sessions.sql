-- 목적: 광고 클릭 흔적이 URL에 남아 있는지 확인 - page_location에 gclid/dclid/utm 파라미터가 있는 세션 비중을 기간·신규/재방문별로 비교.
-- 리타게팅과 검색광고는 구분할 수 없지만, 광고 클릭으로 들어온 세션의 규모와 하락 전후 변화의 상한을 본다. 클릭 없이 노출만 된 경우(view-through)는 보이지 않는다.
-- 기간: 기준선 12/1~12/13, 선행 12/14~12/18, 하락 12/19~1/11, 회복기 1/12~1/31 (세션 날짜 = 세션 첫 이벤트 날짜).
WITH ev AS (
  SELECT user_pseudo_id,
    CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    PARSE_DATE('%Y%m%d', event_date) AS d,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS sn,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location') AS loc,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131'
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
),
s AS (
  SELECT session_key, MIN(d) AS sd, MAX(sn) AS sn,
    LOGICAL_OR(REGEXP_CONTAINS(IFNULL(loc, ''), r'[?&](gclid|dclid|gbraid|wbraid)=')) AS has_click_id,
    LOGICAL_OR(REGEXP_CONTAINS(IFNULL(loc, ''), r'[?&]utm_')) AS has_utm,
    LOGICAL_OR(event_name = 'purchase') AS has_purchase
  FROM ev GROUP BY session_key
)
SELECT CASE WHEN sd <= '2020-12-13' THEN '1 기준선' WHEN sd <= '2020-12-18' THEN '2 선행' WHEN sd <= '2021-01-11' THEN '3 하락' ELSE '4 회복기' END AS period,
  sn > 1 AS returning_session,
  COUNT(*) AS sessions, COUNTIF(has_click_id) AS click_id_sessions, COUNTIF(has_utm) AS utm_sessions,
  COUNTIF(has_click_id AND has_purchase) AS click_id_purchase_sessions, COUNTIF(has_purchase) AS purchase_sessions
FROM s GROUP BY period, returning_session ORDER BY period, returning_session
