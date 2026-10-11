-- 목적: device.operating_system = 'Web'의 정체 확인 ⑤ - device.category = 'mobile'이면서 OS가 'Web'인 이벤트의 상세 필드.
-- 진짜 스마트폰(iPhone/Android)인데 OS 이름만 'Web'으로 기록된 건지, 데스크톱 성격인지 판단하기 위해
-- mobile_brand_name, mobile_model_name, operating_system_version, web_info.browser 상위 값을 본다.
-- 비교 기준으로 mobile이면서 OS가 iOS / Android인 이벤트의 같은 필드도 함께 낸다.

WITH e AS (
  SELECT
    CASE
      WHEN device.operating_system = 'Web' THEN 'mobile + OS=Web'
      WHEN device.operating_system = 'iOS' THEN 'mobile + OS=iOS'
      WHEN device.operating_system = 'Android' THEN 'mobile + OS=Android'
    END AS grp,
    device.mobile_brand_name AS mobile_brand_name,
    device.mobile_model_name AS mobile_model_name,
    device.operating_system_version AS operating_system_version,
    device.web_info.browser AS browser
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND device.category = 'mobile'
    AND device.operating_system IN ('Web', 'iOS', 'Android')
),
vals AS (
  SELECT e.grp, f.field, f.val, COUNT(*) AS n
  FROM e, UNNEST([
    STRUCT('mobile_brand_name' AS field, mobile_brand_name AS val),
    STRUCT('mobile_model_name', mobile_model_name),
    STRUCT('operating_system_version', operating_system_version),
    STRUCT('web_info.browser', browser)
  ]) AS f
  GROUP BY e.grp, f.field, f.val
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY grp, field ORDER BY n DESC) AS rn,
         ROUND(n * 100 / SUM(n) OVER (PARTITION BY grp, field), 2) AS pct
  FROM vals
)
SELECT grp, field, rn, val, n, pct
FROM ranked
WHERE rn <= 6
ORDER BY field, grp, rn
