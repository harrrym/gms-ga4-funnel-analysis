-- 목적: 로그인(계정) 흔적이 있는 유저 비율의 대략적 확인 - user_id는 전부 NULL이라 직접 알 수 없으므로, 로그인·계정 전용 페이지(/signin.html, /myaccount.html, /registersuccess.html) 방문 유저로 근사. 11/1~1/31.
-- 이 페이지를 방문했다고 해서 로그인 성공을 뜻하지는 않는다(로그인 화면 방문, 가입 완료 화면 등). 하한이 아니라 대략적 규모만 본다.
WITH pv AS (
  SELECT user_pseudo_id,
    LOWER(REGEXP_EXTRACT((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location'), r'^https?://[^/]+(/[^?#]*)')) AS path
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131' AND event_name = 'page_view'
)
SELECT COUNT(DISTINCT user_pseudo_id) AS users,
  COUNT(DISTINCT IF(path = '/signin.html', user_pseudo_id, NULL)) AS signin_users,
  COUNT(DISTINCT IF(path = '/myaccount.html', user_pseudo_id, NULL)) AS myaccount_users,
  COUNT(DISTINCT IF(path = '/registersuccess.html', user_pseudo_id, NULL)) AS registersuccess_users,
  COUNT(DISTINCT IF(path IN ('/signin.html', '/myaccount.html', '/registersuccess.html'), user_pseudo_id, NULL)) AS any_account_page_users
FROM pv
