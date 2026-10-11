-- 목적: 봇·이상 활동 점검 ② - 이벤트 수 상위 25개 계정의 활동 패턴. 식별값(user_pseudo_id)은 출력하지 않고 순위만 쓴다.
-- 상위 계정이 실제로 구매/장바구니 행동을 하는지(=사람일 가능성), 아니면 방문만 반복하는지 본다.
-- 마지막 두 행은 상위 N개 계정이 전체 이벤트에서 차지하는 비중.

WITH e AS (
  SELECT
    user_pseudo_id,
    event_name,
    event_date,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sid
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
u AS (
  SELECT
    user_pseudo_id,
    COUNT(*) AS events,
    COUNT(DISTINCT sid) AS sessions,
    COUNT(DISTINCT event_date) AS active_days,
    COUNTIF(event_name = 'page_view') AS page_views,
    COUNTIF(event_name = 'add_to_cart') AS carts,
    COUNTIF(event_name = 'purchase') AS purchases
  FROM e
  GROUP BY user_pseudo_id
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (ORDER BY events DESC) AS rnk,
         SUM(events) OVER () AS total_events
  FROM u
)
SELECT
  CAST(rnk AS STRING) AS rank_label,
  events, sessions, active_days, page_views, carts, purchases,
  ROUND(events / sessions, 1) AS events_per_session,
  ROUND(events * 100 / total_events, 3) AS pct_of_all_events
FROM ranked
WHERE rnk <= 25
UNION ALL
SELECT '상위 100 합계', SUM(events), SUM(sessions), NULL, SUM(page_views), SUM(carts), SUM(purchases), NULL, ROUND(SUM(events) * 100 / ANY_VALUE(total_events), 3)
FROM ranked WHERE rnk <= 100
UNION ALL
SELECT '상위 1000 합계', SUM(events), SUM(sessions), NULL, SUM(page_views), SUM(carts), SUM(purchases), NULL, ROUND(SUM(events) * 100 / ANY_VALUE(total_events), 3)
FROM ranked WHERE rnk <= 1000
ORDER BY SAFE_CAST(rank_label AS INT64) NULLS LAST, rank_label
