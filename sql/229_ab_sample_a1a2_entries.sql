-- 목적: A/B 표본 크기 계산용(A1·A2) - 마감 이후(12/19~1/11) 유저 단위 진입일별 유저 수와 구매 유저 수.
-- A2 진입 = 기간 안 유저의 첫 세션 시작(전체 방문자), A1 진입 = 기간 안 유저의 첫 목록 경로 page_view(목록 방문자).
-- 구매 = 진입 시각 이후(진입 세션 포함) 1/11까지 purchase 이벤트가 있는가. 세션 날짜 = 세션 첫 이벤트 날짜(docs/09와 같은 규칙, 12/18부터 읽어 12/18에 시작한 세션은 제외).
-- OMTM_check 행은 세션 기준 구매전환율이 docs/09(616/82,384)와 같은지 확인용.
WITH ev AS (
  SELECT user_pseudo_id, (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sid, PARSE_DATE('%Y%m%d', event_date) AS d, event_timestamp AS ts, event_name,
    LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201218' AND '20210111'
),
ev2 AS (SELECT *, CONCAT(user_pseudo_id, '-', CAST(sid AS STRING)) AS session_key FROM ev WHERE sid IS NOT NULL),
sess AS (
  SELECT user_pseudo_id, session_key, MIN(ts) AS start_ts, MIN(d) AS sd, LOGICAL_OR(event_name = 'purchase') AS has_purchase
  FROM ev2 GROUP BY user_pseudo_id, session_key
  HAVING MIN(d) BETWEEN '2020-12-19' AND '2021-01-11'
),
pur AS (SELECT user_pseudo_id, ts FROM ev2 WHERE event_name = 'purchase' AND d >= '2020-12-19'),
a2 AS (
  SELECT user_pseudo_id, MIN(start_ts) AS entry_ts, ARRAY_AGG(sd ORDER BY start_ts LIMIT 1)[OFFSET(0)] AS entry_d
  FROM sess GROUP BY user_pseudo_id
),
a1 AS (
  SELECT e.user_pseudo_id, MIN(e.ts) AS entry_ts, ARRAY_AGG(e.d ORDER BY e.ts LIMIT 1)[OFFSET(0)] AS entry_d
  FROM ev2 e JOIN sess s USING (session_key)
  WHERE e.event_name = 'page_view' AND e.path IN ('/asearch.html','/google+redesign/apparel','/google+redesign/apparel/hats','/google+redesign/apparel/kids','/google+redesign/apparel/kids/kids+infant','/google+redesign/apparel/mens','/google+redesign/apparel/mens/mens+t+shirts','/google+redesign/apparel/socks','/google+redesign/apparel/womens','/google+redesign/bags/backpacks/','/google+redesign/campus+collection','/google+redesign/clearance','/google+redesign/drinkware/mugs+tumblers','/google+redesign/eco+friendly','/google+redesign/gift+cards','/google+redesign/lifestyle','/google+redesign/lifestyle/bags','/google+redesign/lifestyle/drinkware','/google+redesign/lifestyle/small+goods','/google+redesign/new','/google+redesign/office','/google+redesign/shop+by+brand','/google+redesign/shop+by+brand/android','/google+redesign/shop+by+brand/google','/google+redesign/shop+by+brand/google+cloud','/google+redesign/shop+by+brand/i+am+remarkable','/google+redesign/shop+by+brand/youtube','/google+redesign/stationery','/google+redesign/stationery/notebooks','/google+redesign/stationery/stickers','/google+redesign/stationery/writing','/store.html')
  GROUP BY e.user_pseudo_id
)
SELECT 'A2' AS grp, entry_d AS d, COUNT(*) AS users,
  COUNTIF(EXISTS(SELECT 1 FROM pur p WHERE p.user_pseudo_id = a.user_pseudo_id AND p.ts >= a.entry_ts)) AS buyers
FROM a2 a GROUP BY entry_d
UNION ALL
SELECT 'A1', entry_d, COUNT(*),
  COUNTIF(EXISTS(SELECT 1 FROM pur p WHERE p.user_pseudo_id = a.user_pseudo_id AND p.ts >= a.entry_ts))
FROM a1 a GROUP BY entry_d
UNION ALL
SELECT 'OMTM_check', NULL, COUNT(*), COUNTIF(has_purchase) FROM sess
ORDER BY grp, d
