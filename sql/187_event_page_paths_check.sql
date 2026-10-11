-- 목적: 상품 상세 페이지 조회를 식별할 수 있는지 확인. 12/1~1/11, 이벤트별 페이지 경로 유형 분포.
-- 경로 유형(경험적 분류): 카테고리 목록(/Google+Redesign/<카테고리>[/<하위>]), store.html, asearch.html, 기타(상품 상세 후보 = 그 밖의 /Google+Redesign/<상품명>), 장바구니/결제(basket/ordercompleted 등)
WITH e AS (
  SELECT
    event_name,
    REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)') AS path
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210111'
    AND event_name IN ('page_view', 'view_item', 'select_item', 'add_to_cart', 'begin_checkout')
)
SELECT event_name, path, COUNT(*) AS events
FROM e GROUP BY event_name, path
QUALIFY ROW_NUMBER() OVER (PARTITION BY event_name ORDER BY COUNT(*) DESC) <= 12
ORDER BY event_name, events DESC
