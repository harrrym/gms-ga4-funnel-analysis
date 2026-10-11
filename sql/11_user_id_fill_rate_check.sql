-- 목적: user_id(로그인 기반 식별자)가 실제로 이 데이터셋에서 얼마나 채워져 있는지 확인한다.
-- user_pseudo_id(쿠키/기기 기반)만 신뢰할 수 있다는 주장을 실제 데이터로 검증하기 위함.

SELECT
  COUNT(*) AS total_events,
  COUNTIF(user_id IS NOT NULL AND user_id != '') AS events_with_user_id,
  ROUND(COUNTIF(user_id IS NOT NULL AND user_id != '') * 100.0 / COUNT(*), 4) AS pct_events_with_user_id,
  COUNT(DISTINCT user_pseudo_id) AS distinct_users,
  COUNT(DISTINCT CASE WHEN user_id IS NOT NULL AND user_id != '' THEN user_pseudo_id END) AS distinct_users_with_user_id
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
