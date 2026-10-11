-- 목적: 상품 사진 클릭을 나타내는 이벤트가 있는지 확인. click 이벤트의 link_url 상위, select_item/click의 event_params 키 목록.
SELECT 'click_link_url' AS kind,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'link_url') AS value,
  COUNT(*) AS n
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131' AND event_name = 'click'
GROUP BY value
UNION ALL
SELECT CONCAT('param_key:', event_name) AS kind, p.key AS value, COUNT(*) AS n
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(event_params) AS p
WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20201207' AND event_name IN ('select_item', 'click', 'view_item_list')
GROUP BY kind, value
ORDER BY kind, n DESC
