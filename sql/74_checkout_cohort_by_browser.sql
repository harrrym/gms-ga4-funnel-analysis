-- 목적: 가설(기술적 문제) 검증 - cart→checkout 하락이 특정 브라우저에 몰려있는지 확인한다.
-- device.category(desktop/mobile/tablet)는 이미 균일하게 하락한 걸 확인했으니(37번), 더 세부적인
-- device.web_info.browser 기준으로 다시 쪼갠다. OS 필드는 'Web' 오염 문제가 있어 여기서는 쓰지 않는다.
-- 37번과 동일한 방법론: 첫 add_to_cart 이벤트의 browser를 기록하고, 하락구간(12/14~1/11) vs 평상시 비교.

WITH first_cart_event AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS first_cart_date,
    device.web_info.browser AS browser
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp ASC) = 1
),
events AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
user_outcome AS (
  SELECT
    fc.user_pseudo_id,
    fc.first_cart_date,
    fc.browser,
    MAX(CASE WHEN e.event_name = 'begin_checkout' AND e.event_date >= fc.first_cart_date THEN 1 ELSE 0 END) AS did_checkout
  FROM first_cart_event fc
  LEFT JOIN events e ON e.user_pseudo_id = fc.user_pseudo_id
  GROUP BY fc.user_pseudo_id, fc.first_cart_date, fc.browser
),
labeled AS (
  SELECT
    *,
    CASE WHEN first_cart_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간' ELSE '평상시' END AS period
  FROM user_outcome
)
SELECT
  browser,
  period,
  COUNT(*) AS users,
  SUM(did_checkout) AS checkout_users,
  ROUND(SAFE_DIVIDE(SUM(did_checkout), COUNT(*)) * 100, 2) AS cart_to_checkout_rate
FROM labeled
GROUP BY browser, period
ORDER BY browser, period
