-- 목적: 품절이 전환율 하락의 원인인지 직접 검정 - "이미 품절 상태인 상품"의 담기가
-- 전체 담기에서 차지하는 비중을 평상시 vs 하락구간으로 비교.
-- 품절 시작일 = 14개 상품 각각의 마지막 판매 주(docs/07) 다음 주 월요일.

WITH stockout_start AS (
  SELECT * FROM UNNEST([
    STRUCT('Google Leather Strap Hat Black' AS item_name, DATE('2020-11-30') AS start_date),
    ('Google Small Standard Journal Navy', DATE('2020-11-30')),
    ('Google Super G Tumbler (Blue Lid)', DATE('2020-12-07')),
    ('Google Infant Charcoal Onesie', DATE('2020-12-07')),
    ('Android Large Trace Journal Black', DATE('2020-12-07')),
    ('Google Leather Strap Hat Blue', DATE('2020-12-14')),
    ('Google Decal', DATE('2020-12-14')),
    ('Google Sunnyvale Campus Mug', DATE('2020-12-14')),
    ('YouTube Transmission Journal Red', DATE('2020-12-14')),
    ('Google Thermal Tumbler Navy', DATE('2020-12-14')),
    ('Google Cork Base Tumbler', DATE('2020-12-14')),
    ('Google Confetti Slim Task Pad', DATE('2020-12-14')),
    ('Google Youth FC Longsleeve Charcoal', DATE('2020-12-14')),
    ('Google Youth Badge Tee Navy', DATE('2020-12-14'))
  ])
),
cart_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    item.item_name AS item_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'add_to_cart'
),
labeled AS (
  SELECT
    c.event_date,
    CASE
      WHEN c.event_date BETWEEN '2020-12-14' AND '2021-01-11' THEN '하락구간'
      WHEN c.event_date BETWEEN '2020-11-23' AND '2020-11-30' THEN '블프구간'
      WHEN c.event_date < '2020-12-14' THEN '평상시'
      ELSE '사후구간'
    END AS period,
    CASE WHEN s.start_date IS NOT NULL AND c.event_date >= s.start_date THEN 1 ELSE 0 END AS is_poststockout
  FROM cart_events c
  LEFT JOIN stockout_start s ON s.item_name = c.item_name
)
SELECT
  period,
  COUNT(*) AS total_cart_adds,
  SUM(is_poststockout) AS poststockout_cart_adds,
  ROUND(SAFE_DIVIDE(SUM(is_poststockout), COUNT(*)) * 100, 4) AS poststockout_pct
FROM labeled
GROUP BY period
ORDER BY period
