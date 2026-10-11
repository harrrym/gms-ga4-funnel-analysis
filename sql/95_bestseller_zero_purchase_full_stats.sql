-- 목적: 품절 의심 베스트셀러 14개(Hats 2개 포함)의 담기/구매를 평상시/하락구간으로 전부 통계 내기.
-- 담기는 유지되는데 구매만 0인 패턴(품절 시그니처)이 다른 상품에도 똑같이 나타나는지 확인.

WITH target_items AS (
  SELECT item_name FROM UNNEST([
    'Google Leather Strap Hat Blue', 'Google Decal', 'Google Thermal Tumbler Navy',
    'Google Sunnyvale Campus Mug', 'Google Small Standard Journal Navy', 'Google Leather Strap Hat Black',
    'Google Infant Charcoal Onesie', 'Google Confetti Slim Task Pad', 'Google Cork Base Tumbler',
    'Google Youth FC Longsleeve Charcoal', 'Google Youth Badge Tee Navy', 'Google Super G Tumbler (Blue Lid)',
    'Android Large Trace Journal Black', 'YouTube Transmission Journal Red'
  ]) AS item_name
),
cart_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    item.item_name AS item_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
    AND item.item_name IN (SELECT item_name FROM target_items)
),
purchase_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    item.item_name AS item_name,
    item.item_category AS category
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND item.item_name IN (SELECT item_name FROM target_items)
),
cart_agg AS (
  SELECT
    item_name,
    COUNTIF(event_date < '2020-12-14') AS add_to_cart_baseline,
    COUNTIF(event_date BETWEEN '2020-12-14' AND '2021-01-11') AS add_to_cart_decline
  FROM cart_events
  GROUP BY item_name
),
purchase_agg AS (
  SELECT
    item_name,
    ANY_VALUE(category) AS category,
    COUNTIF(event_date < '2020-12-14') AS purchase_baseline,
    COUNTIF(event_date BETWEEN '2020-12-14' AND '2021-01-11') AS purchase_decline
  FROM purchase_events
  GROUP BY item_name
)
SELECT
  t.item_name,
  pu.category,
  IFNULL(ca.add_to_cart_baseline, 0) AS add_to_cart_baseline,
  IFNULL(ca.add_to_cart_decline, 0) AS add_to_cart_decline,
  IFNULL(pu.purchase_baseline, 0) AS purchase_baseline,
  IFNULL(pu.purchase_decline, 0) AS purchase_decline
FROM target_items t
LEFT JOIN cart_agg ca ON ca.item_name = t.item_name
LEFT JOIN purchase_agg pu ON pu.item_name = t.item_name
ORDER BY purchase_baseline DESC
