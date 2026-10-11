-- 목적: 지금까지 item_name으로 집계한 결과가 item_id 기준으로도 똑같이 나오는지 교차검증.
-- 혹시 item_name이 여러 item_id에 걸쳐 있거나(동명이상품), item_id가 바뀌어서
-- "구매 0건"이 착시였을 가능성을 배제.

WITH target_items AS (
  SELECT item_name FROM UNNEST([
    'Google Leather Strap Hat Blue', 'Google Decal', 'Google Thermal Tumbler Navy',
    'Google Sunnyvale Campus Mug', 'Google Small Standard Journal Navy', 'Google Leather Strap Hat Black',
    'Google Infant Charcoal Onesie', 'Google Confetti Slim Task Pad', 'Google Cork Base Tumbler',
    'Google Youth FC Longsleeve Charcoal', 'Google Youth Badge Tee Navy', 'Google Super G Tumbler (Blue Lid)',
    'Android Large Trace Journal Black', 'YouTube Transmission Journal Red'
  ]) AS item_name
),
-- 1. item_name <-> item_id 매핑이 1:1인지 확인
id_mapping AS (
  SELECT
    item.item_name AS item_name,
    item.item_id AS item_id,
    COUNT(*) AS n
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND item.item_name IN (SELECT item_name FROM target_items)
  GROUP BY item_name, item_id
),
-- 2. item_id 기준으로 재집계 (item_name 대신 item_id로 그룹핑)
purchase_by_id AS (
  SELECT
    item.item_id AS item_id,
    item.item_name AS item_name,
    PARSE_DATE('%Y%m%d', event_date) AS event_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND item.item_id IN (SELECT item_id FROM id_mapping)
)
SELECT
  item_id,
  ANY_VALUE(item_name) AS item_name,
  COUNTIF(event_date < '2020-12-14') AS purchase_baseline_by_id,
  COUNTIF(event_date BETWEEN '2020-12-14' AND '2021-01-11') AS purchase_decline_by_id
FROM purchase_by_id
GROUP BY item_id
ORDER BY purchase_baseline_by_id DESC
