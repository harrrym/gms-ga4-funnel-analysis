-- 목적: 구매 유저의 "담기 기록 보유율"을 주별로 확인 - 0개 결제시작이 가짜 이벤트인지,
-- 상품정보만 빠진 진짜 결제시작인지 판단하는 보조 근거.

WITH first_purchase_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_purchase_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp ASC) = 1
),
any_cart AS (
  SELECT DISTINCT user_pseudo_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
)
SELECT
  DATE_TRUNC(fp.first_purchase_date, WEEK(MONDAY)) AS week_start,
  COUNT(*) AS purchasing_users,
  COUNTIF(ac.user_pseudo_id IS NOT NULL) AS with_cart_record,
  ROUND(SAFE_DIVIDE(COUNTIF(ac.user_pseudo_id IS NOT NULL), COUNT(*)) * 100, 2) AS with_cart_pct
FROM first_purchase_event fp
LEFT JOIN any_cart ac ON ac.user_pseudo_id = fp.user_pseudo_id
GROUP BY week_start
ORDER BY week_start
