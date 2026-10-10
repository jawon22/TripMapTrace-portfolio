# 결정 기록 (DECISIONS)

기획/디자인/논의에서 **확정된 결정**만 기록한다. 새 결정은 위에 추가(최신순).
형식: `날짜 — 결정 (이유) [관련 파일/계획]`

> 아래 항목은 기존 `PROJECT_CONTEXT.md`에서 옮겨 적은 초기 기록이다.

## 2026-07-05
- 딥링크는 https App Links를 추가하되 커스텀 스킴(`tripmaptrace://`)도 **유지**한다. (QR 대면 스캔·구버전 호환, 비파괴) [`.claude/plans/deeplink-applinks-plan.md`]
- 초대 링크 시트는 진입 시 유효 토큰을 자동 확보하고 만료/재발급 UI는 제거한다. (단순화) [`.claude/plans/invite-ux-revamp.md`]

## 2026-05
- 멤버 태그(C-4)는 **취소**. (닫힌 여행 공간에서 실용성 낮음)
- 달력 년/월 피커는 **제외**, "오늘" 버튼만 둔다. (단순화)
- 풀스크린 뷰어에 `photo_view` 패키지는 쓰지 않는다. (`InteractiveViewer` + `PageView` + `VideoPlayer`로 충분)
- 지도 타일은 CartoDB Voyager로 통일한다. (API 키 불필요, 도로/지명 포함)

## 2026-04
- Apple 로그인은 **보류**. (Mac + Xcode + Apple Developer Program $99 필요)

## 2026-03
- 영상 썸네일은 서버(FFmpeg)가 아니라 Flutter 클라이언트(`video_thumbnail`)에서 추출해 업로드한다. (FFmpeg 불필요)
