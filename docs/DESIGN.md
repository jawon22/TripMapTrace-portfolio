# 디자인 (DESIGN)

화면 방향, 톤, 디자인 규칙을 정리한다. 토큰의 실제 값은 코드(`app/lib/theme/`)가 단일 출처다.

## 디자인 토큰
- 색상/간격/모서리/타이포는 `app/lib/theme/`의 `AppColors`·`AppSpacing`·`AppRadius`·`AppTextStyles`를 사용한다.
- 새 화면·수정 시 하드코딩 대신 토큰을 참조한다. (기존 화면은 손댈 때 점진 치환)
- 폰트는 Pretendard.

## AppBar 표면 위계
- 루트 4탭(홈·커뮤니티·글로벌 지도·프로필): **라이트 앱바** (`app_theme` 기본값)
- 여행 상세·풀스크린 등 몰입 화면: **다크 앱바** (각 화면에서 개별 설정)

## 화면 흐름
`LoginScreen` / `OnboardingScreen` → `MainScreen`(하단 4탭: 홈 / 커뮤니티 / 글로벌 지도 / 프로필) → `TripDetailScreen`(타임라인 / 지도, EDITOR 이상은 업로드 탭 추가)

## 지도
- 타일: CartoDB Voyager
- GPS 없는 미디어는 촬영 시각 기준 가장 가까운 GPS 지점에 근사 배치하고 주황 테두리로 구분한다.
- 마커는 원형 카드, 같은 위치는 최대 3장 스택.

## 디자인 논의 메모
<!-- 확정 전 논의는 여기에, 확정되면 위 규칙에 반영하고 DECISIONS.md에 기록한다. -->
- (없음)
