-- 목적: user_properties에 어떤 키가 있는지, user_ltv 값이 실제로 0 초과인 이벤트가 있는지 확인.
SELECT CONCAT('user_properties:', up.key) AS item, COUNT(*) AS events, COUNT(DISTINCT user_pseudo_id) AS users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(user_properties) up
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY item
UNION ALL
SELECT 'user_ltv.revenue>0', COUNTIF(user_ltv.revenue > 0), COUNT(DISTINCT IF(user_ltv.revenue > 0, user_pseudo_id, NULL))
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
