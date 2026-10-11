-- 목적: OMTM 세션 단위 방문->담기를 신규/재방문, 채널별로 분해 (12월 초 vs 하락구간).
-- 세션 정의는 sql/01·sql/181과 동일(user+ga_session_id, ga_session_id NULL 제외). 신규 = ga_session_number=1.
-- 채널은 sql/166과 같은 분류(traffic_source = 유저 최초 유입 기준이라 세션 단위 값이 아님에 주의).
WITH ev AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
    event_name,
    CASE
      WHEN traffic_source.source = 'google' AND traffic_source.medium = 'organic' THEN 'google/organic'
      WHEN traffic_source.source = '(direct)' AND traffic_source.medium = '(none)' THEN 'direct'
      WHEN traffic_source.source = 'google' AND traffic_source.medium = 'cpc' THEN 'google/cpc'
      WHEN traffic_source.source = 'shop.googlemerchandisestore.com' AND traffic_source.medium = 'referral' THEN 'self-referral'
      ELSE '식별불가/기타'
    END AS channel
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210111'
),
sessions AS (
  SELECT
    CASE WHEN event_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '12월 초' END AS period,
    CONCAT(user_pseudo_id, '-', CAST(session_id AS STRING)) AS session_key,
    MAX(session_number) = 1 AS is_new,
    ANY_VALUE(channel) AS channel,
    LOGICAL_OR(event_name = 'add_to_cart') AS has_cart,
    LOGICAL_OR(event_name = 'purchase') AS has_purchase
  FROM ev
  WHERE session_id IS NOT NULL
  GROUP BY period, session_key
)
SELECT period, is_new, channel,
  COUNT(*) AS sessions, COUNTIF(has_cart) AS cart_sessions, COUNTIF(has_purchase) AS purchase_sessions
FROM sessions
GROUP BY period, is_new, channel
ORDER BY period, is_new, channel
