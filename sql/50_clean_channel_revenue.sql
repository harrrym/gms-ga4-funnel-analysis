-- [transaction_id 통합 키] transaction_id는 2020-11-01~11-12 구간에서는 int_value 칸에, 이후에는 string_value 칸에 저장돼 있다.
-- string_value만 읽으면 int_value 칸의 456행을 "번호 없음"으로 잘못 처리하므로 두 칸을 COALESCE로 합쳐 하나의 키로 쓴다 (docs/05 참고).
-- 목적: 33번 채널별 7일 윈도우 매출의 정제본 (같은 transaction_id는 1건만 남김).
-- 채널 분류와 7일 윈도우, 전환자 정의(윈도우 내 매출>0)는 33번과 동일하다. 달라진 것은 매출 합산에서 중복을 제거한 것뿐.

WITH session_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
    traffic_source.source AS source,
    traffic_source.medium AS medium
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
new_users AS (
  SELECT
    user_pseudo_id,
    MIN(event_date) AS first_date,
    ANY_VALUE(source) AS source,
    ANY_VALUE(medium) AS medium
  FROM session_events
  WHERE session_number = 1 AND session_id IS NOT NULL
  GROUP BY user_pseudo_id
),
purchases_raw AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    event_timestamp,
    COALESCE(
      (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'transaction_id'),
      CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS STRING)
    ) AS transaction_id,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),
purchases AS (
  SELECT *
  FROM purchases_raw
  WHERE TRUE
  QUALIFY transaction_id IS NULL
       OR ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY event_timestamp) = 1
),
channeled AS (
  SELECT
    nu.user_pseudo_id,
    CASE
      WHEN nu.source = 'google' AND nu.medium = 'organic' THEN 'google/organic'
      WHEN nu.source = '(direct)' AND nu.medium = '(none)' THEN 'direct'
      WHEN nu.source = 'google' AND nu.medium = 'cpc' THEN 'google/cpc'
      WHEN nu.source = 'shop.googlemerchandisestore.com' AND nu.medium = 'referral' THEN 'self-referral'
      ELSE '식별불가/기타'
    END AS channel,
    nu.first_date
  FROM new_users nu
),
window_revenue AS (
  SELECT
    c.channel,
    c.user_pseudo_id,
    SUM(IF(p.event_date IS NOT NULL AND DATE_DIFF(p.event_date, c.first_date, DAY) BETWEEN 0 AND 7, p.revenue, 0)) AS revenue_7d
  FROM channeled c
  LEFT JOIN purchases p USING (user_pseudo_id)
  GROUP BY c.channel, c.user_pseudo_id
)
SELECT
  channel,
  COUNT(*) AS new_users,
  COUNTIF(revenue_7d > 0) AS converters,
  ROUND(SUM(revenue_7d), 2) AS total_revenue_7d,
  ROUND(SAFE_DIVIDE(SUM(revenue_7d), COUNT(*)), 3) AS revenue_per_new_user,
  ROUND(SAFE_DIVIDE(SUM(revenue_7d), COUNTIF(revenue_7d > 0)), 2) AS revenue_per_converter
FROM window_revenue
GROUP BY channel
ORDER BY total_revenue_7d DESC
