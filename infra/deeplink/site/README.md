# Netlify 배포용 정적 사이트 (App Links)

이 폴더(`site/`)를 그대로 Netlify에 올리면 카톡 초대 링크 클릭이 동작한다.

## 구성
- `well-known/assetlinks.json` — 앱↔도메인 소유 검증(debug 키 SHA-256 채워짐).
  - ⚠️ 점 폴더 `.well-known`는 브라우저 드래그 시 크로미움이 제외하므로 **일반 폴더**에 두고,
    `_redirects`가 `/.well-known/assetlinks.json` → `/well-known/assetlinks.json`으로 200 rewrite.
- `invite-fallback.html` — 앱 미설치 시 열리는 초대 코드 안내 페이지.
- `_redirects` — `/.well-known/assetlinks.json` 매핑 + `/invite/*` → 폴백 페이지 rewrite.

## 배포 (드래그&드롭)
1. https://app.netlify.com 로그인 → **Add new site → Deploy manually**.
2. 이 `site/` 폴더를 통째로 드롭.
3. 배포되면 `https://랜덤이름.netlify.app` 주소가 나옴 → Site settings에서 원하는 이름으로 변경 가능.
4. 확인:
   - `https://{host}/.well-known/assetlinks.json` 접속 → JSON 보이면 OK.
   - `https://{host}/invite/testtoken` 접속 → 초대 코드 "testtoken" 보이면 OK.

## 배포 후
정해진 `{host}`를 알려주면 앱/백엔드 코드에 https 링크를 비파괴적으로 연결한다.
(자세한 흐름: `.claude/plans/deeplink-applinks-plan.md`)
