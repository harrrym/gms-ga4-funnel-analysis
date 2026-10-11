-- 목적: 배송 관련 컬럼·이벤트가 있는지 확인 - (1) ecommerce.shipping_value 값, (2) 배송/결제 단계 이벤트(add_shipping_info 등), (3) 이벤트 파라미터 키 중 ship/deliver 포함. 11/1~1/31.
SELECT 'purchase_shipping_value' AS item, CAST(COUNT(*) AS STRING) AS a, CAST(COUNTIF(ecommerce.shipping_value_in_usd IS NOT NULL) AS STRING) AS b,
  CAST(COUNTIF(ecommerce.shipping_value_in_usd > 0) AS STRING) AS c, CAST(ROUND(SUM(ecommerce.shipping_value_in_usd), 1) AS STRING) AS d
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131' AND event_name = 'purchase'
UNION ALL
SELECT CONCAT('event_name:', event_name), CAST(COUNT(*) AS STRING), CAST(COUNT(DISTINCT user_pseudo_id) AS STRING), NULL, NULL
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY event_name
UNION ALL
SELECT CONCAT('param_key:', p.key), CAST(COUNT(*) AS STRING), NULL, NULL, NULL
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(event_params) p
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131' AND REGEXP_CONTAINS(LOWER(p.key), r'ship|deliver|carrier|tier|address|zip|postal')
GROUP BY p.key
