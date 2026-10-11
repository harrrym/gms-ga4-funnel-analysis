-- 목적: device.operating_system = 'Web'의 정체 확인 ② - OS가 'Web'인 이벤트와 아닌 이벤트의 다른 필드 비교.
-- platform(최상위), stream_id, device.web_info.browser, device.mobile_brand_name, device.operating_system_version 값 분포(상위 8개)를 나란히 본다.
-- (이 데이터셋에는 device.browser가 없고 브라우저는 device.web_info.browser에 있다.)

WITH e AS (
  SELECT
    IF(device.operating_system = 'Web', 'OS=Web', 'OS=기타') AS os_group,
    platform AS platform,
    CAST(stream_id AS STRING) AS stream_id,
    device.web_info.browser AS browser,
    device.mobile_brand_name AS mobile_brand_name,
    device.operating_system_version AS operating_system_version
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
vals AS (
  SELECT e.os_group, f.field, f.val, COUNT(*) AS n
  FROM e, UNNEST([
    STRUCT('platform' AS field, platform AS val),
    STRUCT('stream_id', stream_id),
    STRUCT('web_info.browser', browser),
    STRUCT('mobile_brand_name', mobile_brand_name),
    STRUCT('operating_system_version', operating_system_version)
  ]) AS f
  GROUP BY e.os_group, f.field, f.val
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY os_group, field ORDER BY n DESC) AS rn,
         ROUND(n * 100 / SUM(n) OVER (PARTITION BY os_group, field), 2) AS pct
  FROM vals
)
SELECT os_group, field, rn, val, n, pct
FROM ranked
WHERE rn <= 8
ORDER BY field, os_group, rn
