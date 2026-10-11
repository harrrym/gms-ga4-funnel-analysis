-- 목적: begin_checkout 이벤트 자체에 그 시점 장바구니 상품(items)이 들어있는지 확인.
-- GMS는 장바구니 전체를 한 번에 결제하는 구조(체크박스 부분선택 없음)라, begin_checkout의 items가
-- "결제시작 시점의 카트 전체"를 그대로 담고 있을 가능성이 높다. 사실이면 add_to_cart를 재구성할 필요 없이
-- begin_checkout의 items를 바로 "결제시작 상품 구성"으로 쓸 수 있다.

SELECT
  COUNT(*) AS begin_checkout_events,
  COUNTIF(ARRAY_LENGTH(items) > 0) AS events_with_items,
  ROUND(AVG(ARRAY_LENGTH(items)), 2) AS avg_items_per_event
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'begin_checkout'
