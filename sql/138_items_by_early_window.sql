-- 목적: 대조군 재설계용 - 11/1~11/15 구매만으로 "평상시 구매 20건 이상" 상품을 다시 선정.
-- (이전 선정 기준(전체 평상시)은 평가 윈도우와 겹쳐서 순환 참조 문제가 있었음)

SELECT
  item.item_name AS item_name,
  COUNT(*) AS purchases_11_01_to_11_15
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20201115'
  AND event_name = 'purchase'
  AND item.item_name IS NOT NULL
GROUP BY item_name
HAVING COUNT(*) >= 20
ORDER BY purchases_11_01_to_11_15 DESC
