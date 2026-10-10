# TripMapTrace 종합 진단 & 정리 로드맵

> 작성일: 2026-06-27
> 목적: 7~8단계까지 누적된 기능을 출시 관점에서 점검하고, 다듬을 순서를 단계별로 정리한다.
> 이 문서는 **진단 + 로드맵**이며, 실제 코드 수정은 이 문서를 토대로 추후 별도 진행한다.

---

## 한눈에 보는 결론

앱은 여행 생성 → 미디어 업로드 → 타임라인/지도 → 커뮤니티 공유까지 **핵심 루프가 이미 완성**되어 있다.
지금 필요한 건 **새 기능이 아니라 정리**다.

> **"기능이 많은 게 아니라, 같은 목적의 UI가 여러 진입점에 흩어져 '많아 보이는' 상태"**
> → 다만 코드 재확인 결과 *내부 중복은 크지 않았다*: 뷰어는 이미 3곳이 공유 중이고, 댓글 시트 분리는 정당했다(A.2 참고). 진짜 정리 포인트는 **사용자 동선의 일관성**(미디어 보는 경로 5가지, 지도 3곳)이다.

방향: **(1) 출시 안정성 확보 → (2) 중복 통합·일관화 → (3) 제품 완성도**

---

## A. 5개 관점 진단

| 관점            | 점수  | 요약                                                                |
| --------------- | ----- | ------------------------------------------------------------------- |
| 기능 (Feature)  | ★★★★☆ | 핵심 루프 완비, 22개 마이그레이션 체계적. 단 댓글 동작 불일치.      |
| 구조 (Code)     | ★★★★☆ | 백엔드 feature 패키지·DTO 분리 깔끔. 단 프론트 뷰어/댓글 위젯 중복. |
| UI/UX           | ★★★☆☆ | 로딩/에러/빈상태 처리 양호. 단 미디어 보는 경로 5가지로 분산.       |
| 디자인 (Visual) | ★★★★★ | Pretendard + AppColors + AppTheme로 일관성 매우 높음.               |
| 보안/안정성     | ★★★☆☆ | **출시 차단 요소 있음** (댓글 API 권한 구멍).                       |

### 1. 기능 — ★★★★☆

**강점**: 여행 CRUD, 멤버/역할(OWNER/EDITOR/VIEWER), 초대(딥링크/QR), 3단계 S3 업로드, EXIF 기반 타임라인, 경로 지도, 좋아요/댓글, 커뮤니티 피드, 게스트 둘러보기, FCM 알림, 소셜로그인(구글/카카오), 비밀번호 재설정, 계정 탈퇴까지 완비.

**약점 (기능 일관성)**

- ⚠️ **댓글 동작 불일치**: 미디어 댓글은 **수정 불가**(`Comment` 엔티티에 update 메서드 없음), 커뮤니티 여행 댓글은 **수정 가능**(`TripComment.updateContent`). 같은 "댓글"인데 동작이 달라 혼란.
- ⚠️ **다운로드 진입점 1곳뿐**: 타임라인 선택 모드에서만 가능. 풀스크린 뷰어 등에서 개별 저장 불가.

### 2. 구조 — ★★★★☆

**강점**: 백엔드 `<feature>/{api,domain,repository,service}` 패키지 구조 깔끔, DTO record 분리, `@Transactional` 명확, S3 dual-endpoint(internal/external) 설계 합리적. Flutter도 `models/services/screens/widgets` 분리.

**약점 (중복) — 코드 재확인 후 보정**

- 🟢 **풀스크린 뷰어는 사실 거의 통합돼 있음**(초기 진단 "4~5종"은 과장이었음): `FullscreenViewer`(`timeline_tab.dart`) 하나를 **타임라인·지도·프로필 3곳이 이미 공유**한다. `_MyMediaSheet`는 뷰어가 아니라 그리드 시트(내부에서 `FullscreenViewer` 호출). **별개 구현은 커뮤니티 `_FullscreenGallery`(~45줄) 하나뿐.** → 대규모 리팩터링 불필요. 작은 정리만 권장(아래 Phase 2).
- 🟢 **댓글 바텀시트 2벌은 분리가 정당함**(합치지 말 것): 두 시트는 모델(`CommentItem` vs `CommunityCommentResponse`)·API(`fetchComments(tripId,mediaId)` vs `fetchCommunityComments(tripId)`)·테이블(`comments` vs `trip_comments`)·키 단위(미디어 vs 여행)가 다르다. UI 껍데기만 ~60% 유사. 억지 통합 시 추상화 비용이 중복 비용보다 커짐 → **현행 분리 유지가 옳은 설계.**
- ✅ `UserService` import 중복 — **정리 완료**(2026-06-27, 중복 `TripRole` import 제거).

### 3. UI/UX — ★★★☆☆

**강점**: 로딩/에러/빈 상태 일관 처리, 풀-투-리프레시(빈 상태 포함), 좋아요 스케일 애니메이션, 역할 뱃지 등 디테일 양호.

**약점 (동선) — 코드 재확인 후 보정**

- ⚠️ **미디어 보는 경로 5가지 = 진짜 약점**: 홈→타임라인 / 프로필→내미디어 / 커뮤니티→갤러리 / 지도→마커 / 지도→하단패널. 경로는 자연스러우나 **도착 화면이 둘로 갈림** — 여행 내부는 `FullscreenViewer`(댓글·좋아요·다운로드 완비), 커뮤니티만 `_FullscreenGallery`(반쪽 + 영상 깨짐). 도달 경로마다 보이는 게 달라 일관성 저하.
  - **★ 해결책 = 뷰어 통합 (구조 A.2 ↔ UI/UX 공통 작업)**: 커뮤니티 `_FullscreenGallery`를 `FullscreenViewer`로 흡수하면 *코드 중복 제거(구조)* 와 *미디어 경험 일관화(UI/UX)* 가 **한 작업으로 동시 해결**된다. → Phase 2 항목과 동일 작업(별개 아님).
- 🟡 **지도 3곳은 통합 대상 아님**: 글로벌 지도탭 / 여행 지도탭 / 커뮤니티 경로지도 — 목적이 실제로 다름(전체 여행 / 한 여행 동선 / 남의 여행 구경). 셋이 비슷해 보여 "또 지도?" 인상을 줄 뿐 → **헤더 라벨로 정체성만 구분**하면 됨(외형 마감, Phase 3 선택 항목).
- 🟢 **홈 복귀 동선은 정상**(초기 진단 "약함"은 과장): `TripDetailScreen`이 `MainScreen` 위에 `Navigator.push`되는 표준 패턴(`home_tab.dart:489` 등)이라, 깊은 화면에서도 뒤로가기로 하단탭 있는 `MainScreen`에 복귀된다. 여행상세에서 하단탭이 가려지는 건 의도된 정상 동작 → **수정 불필요.**

### 4. 디자인 — ★★★★★

**강점 — 코드 재확인 후 보강**: 이미 **디자인 시스템 수준**이다. `AppColors`(시맨틱 토큰 13개: primary/accent/role별 3색/destructive 등) + `AppTheme.light()`(Material3 위에 AppBar·3종 버튼·Input·Card·BottomNav·TabBar·Progress·Divider를 **중앙에서 테마링**). radius 12 / 버튼 높이 48 / Pretendard 4 weight 일관. → **외부 UI 키트로 갈아끼울 이득 없음**(이미 80~90% 구현됨). 방향은 *전면 교체*가 아니라 *토큰 토대 확장*.

**약점 (사소) — "하나씩 만들기"가 아니라 "흩어진 값을 토큰으로 모으기"로 해결**

- 색 팔레트에 **success/warning/info 없음** → 성공 SnackBar가 다크네이비로 묻힘. (현재 토큰은 destructive만 보유)
- spacing/radius/타이포가 화면마다 **하드코딩 분산**(`fontSize: 14`, `EdgeInsets.all(16)` 등) → 토큰화 여지.
- 앱바 색이 화면마다 다름(루트탭=라이트 / 여행상세·커뮤니티=다크네이비) — 실제로 합리적 위계이나 **규칙으로 명문화되지 않음**.

> **결론**: 라이브러리 전면 도입(❌) vs 토큰 다듬기(✅) 중 **토큰 다듬기 채택**(사용자 결정). 상세 작업은 Phase 3 참고.

### 5. 보안/안정성 — ★★★☆☆ (출시 차단 요소 있음)

- 🔴 **IDOR(권한 구멍)**: `media/service/CommentService.java`의 `list()`(42행)·`create()`(67행)가 **TripMember 검사 없이** 미디어-trip 소속만 확인. 비공개 여행이라도 tripId/mediaId만 알면 로그인한 외부 사용자가 댓글을 조회·작성 가능. (대조: 같은 모듈 `MediaService`는 전 메서드가 멤버 체크 보유 — 아래 참고) → **코드로 확인 완료.**
  - ✅ **`MediaService`는 오히려 권한 모범 사례**(코드 정독 확인): `presignUpload`/`complete`/`getDownloadUrl`/`updateLocation`/`deleteMedia`는 멤버 체크 + VIEWER 차단, `list`/`toggleLike`는 `existsByTripIdAndUserId`, `listMyMedia`는 본인 것만. → **IDOR 수정 시 이 패턴을 그대로 이식**하면 됨.
- 🔴 **글로벌 예외 핸들러 부재 (새 발견, NPE보다 근본 문제)**: `@ControllerAdvice`/`@ExceptionHandler`가 프로젝트 전체에 **없음**(grep 확인). 서비스들이 권한 거부·잘못된 요청을 `IllegalStateException`으로 던지는데(예: `MediaService` "업로드 권한이 없습니다", "해당 여행의 멤버가 아닙니다") 핸들러가 없어 **Spring 기본 동작으로 전부 500**으로 나감.
  - **API 정합성**: 403/400이어야 할 응답이 클라이언트엔 500 → 앱이 "권한 없음"을 "서버 오류"로 오인.
  - **보안**: 500은 내부 메시지/스택트레이스 노출 위험.
  - **일관성**: 같은 `MediaService` 안에서도 일부는 `ResponseStatusException`(올바름), 일부는 `IllegalStateException`(→500)으로 혼재.
- 🟡 `MediaService` S3 예외 처리에서 `e.awsErrorDetails()` null 가능성(NPE 위험, `MediaService.java:137`). ← 위 핸들러 부재의 한 사례(`IllegalStateException`이라 500).
- 🟡 기존 기술부채: 리프레시 토큰 미구현, HTTPS 미적용 — 공개 배포(스토어 등록) 전 필수.

---

## B. 단계별 정리 로드맵

### Phase 1 — 출시 안정성 (보안·정합성) ✅ 구현·검증 완료 (2026-06-30)

> 구현 계획·검증 결과: [`.claude/plans/phase1-security.md`](./.claude/plans/phase1-security.md). 백엔드 `./gradlew build` 통과 + 로컬 런타임 검증(비멤버 GET/POST/PATCH→403, 본인 PATCH→200, 토큰없음→401, 빈 content→400) + Flutter `flutter analyze` 무결.

- [x] **CommentService 권한 보강** — `list/create/update/delete` 진입부에 `requireMember`(`existsByTripIdAndUserId`, 비멤버 403) 추가. `list`는 `userId`를 받도록 시그니처 변경 + 컨트롤러 전달. → **IDOR 차단 런타임 확인.**
- [x] **댓글 동작 일관화 → 미디어 댓글도 수정 허용으로 통일**. 댓글의 _대상_ 차이는 그대로 둠(미디어 댓글=사진/영상 단위, 커뮤니티 댓글=여행 단위). *동작*만 맞춤.
  - 백엔드: `Comment.updateContent()` + `CommentService.update()`(본인만 403) + `CommentController` `@PatchMapping("/{commentId}")`. (컬럼 추가 없음 → 마이그레이션 불필요)
  - Flutter: `api_service.updateComment()` + `_CommentSheet`에 `_editingCommentId` 수정 UI 이식(커뮤니티 패턴 재사용 — 수정 아이콘·수정중 배너·send/check 전환).
- [x] **글로벌 예외 핸들러 신설** (`config/GlobalExceptionHandler.java`, `@RestControllerAdvice`) — `IllegalStateException`/`IllegalArgumentException`→**400**. `ResponseStatusException`·`@Valid` 검증 실패는 의도적으로 미가로채(회귀 방지) → Spring 기본 상태코드 유지. 권한 거부가 500으로 새던 문제 해소.
  - ※ generic `Exception`→500 핸들러는 `@Valid`(400)·`ResponseStatusException`을 잘못 500으로 바꾸는 회귀 위험이라 **두지 않음**(Spring 기본도 스택 비노출). 사용자 "최소 변경·안전" 결정 반영.
- [x] **`MediaService.java:137` `e.awsErrorDetails()` null-safe 처리** — NPE 방지.
- [x] ~~`UserService` import 중복 제거~~ — **완료**(2026-06-27).
- [ ] (조건부) 리프레시 토큰·HTTPS는 스토어 배포 시점 항목으로 명시. ← **미진행(범위 밖)**

### Phase 2 — 사용성·구조 정리 (UX 부채) ✅ 구현·검증·커밋 완료 (2026-07-05, `5e87c35`)

> 구현 계획: [`.claude/plans/phase2-viewer.md`](./.claude/plans/phase2-viewer.md). 검증: `flutter analyze` 0 error + 위젯 테스트 3종 통과 + 실 DB/MinIO/커뮤니티 API로 영상 경로 실증.

- [x] **`FullscreenViewer`를 `widgets/`로 이동**(완료) — `widgets/fullscreen_viewer.dart` 신설, 4개 화면(타임라인·지도·프로필·커뮤니티)이 공유. `_LikeButton`→`LikeButton` public 승격.
- [x] **커뮤니티 `_FullscreenGallery` → `FullscreenViewer` 흡수**(완료) — ⭐ **구조 중복 제거 + UI/UX 미디어 경험 일관화를 한 번에 해결한 핵심 작업**. `CommunityMediaItem→MediaItem` 어댑터로 재사용, `_FullscreenGallery` 삭제.
  - **부수 효과: 커뮤니티 영상 깨짐 버그 수정 완료** — 기존 `_FullscreenGallery`는 type 무관 `Image.network(downloadUrl)`로 영상이 깨졌으나, 이제 뷰어의 `_VideoPage` 경로로 재생. (실 DB VIDEO 1건 + MinIO mp4 객체 2.6MiB + 커뮤니티 API `type=VIDEO`+presigned URL 실증.)
  - 검증 완료: 백엔드가 영상에도 mp4 presigned `downloadUrl` + `type='VIDEO'` 제공(`CommunityService.java:120-121`), `FullscreenViewer`는 type 분기로 영상을 `_VideoPage`(스트리밍 재생)로 보냄(`timeline_tab.dart:705-707`). 여행 상세 타임라인과 동일한 검증된 경로 → 네트워크 설정 추가 불필요.
- [x] ~~댓글 바텀시트 공통화~~ — **하지 않기로 결정.** 두 시트는 테이블/엔드포인트/키 단위가 달라 분리가 정당함(위 A.2 참고). 통합 시 추상화 비용 > 중복 비용.
- [x] **풀스크린 뷰어 단건 다운로드 추가**(완료) — 뷰어 AppBar 우측 상단 다운로드 아이콘. `canDownload` 플래그 주입.
  - ① **권한 게이트**: 타임라인·지도=`myRole != 'VIEWER'` / 프로필=항상 / 커뮤니티=숨김(기본값 false).
  - ② **중복 방지**: `saveUrlToGallery(url,isVideo,id)` 헬퍼로 묶어 타임라인 일괄 다운로드와 공유.
  - ③ **간소화**: 백엔드가 목록 응답에 풀해상도 `downloadUrl`을 항상 채우므로(`MediaService.toResponse`) 뷰어는 `tripId` 없이 `item.downloadUrl`만으로 저장 → 프로필(tripId 없음) 문제 자동 해결.
- [x] ~~홈 복귀 등 전역 네비 동선 보완~~ — **코드 확인 결과 정상 push/pop 동작**(`TripDetailScreen`은 `MainScreen` 위에 push, 뒤로가기로 하단탭 복귀). 수정 불필요로 종결.

### Phase 3 — 제품 완성도 (매력)

> 진행 순서: 매력·마감 항목 먼저, **앱 브랜딩은 맨 마지막**(출시 직전).

- [x] **디자인 토큰 다듬기 1~3단계** ✅ 구현·검증·커밋 완료 (2026-07-05, `23ec574`) — 계획: [`.claude/plans/phase3-design-tokens.md`](./.claude/plans/phase3-design-tokens.md).
  - 1단계: `AppColors`에 `success/warning/info/border` 추가 + `app_spacing.dart`/`app_radius.dart`/`app_text_styles.dart` 신설.
  - 2단계: `app_theme.dart` 하드코딩(radius·border·spacing)을 토큰으로 치환(시각 무변경).
  - 3단계: 성공 SnackBar 색 → `success`(초록) / 앱바 표면 위계 규칙 명문화(`app_theme`·`CLAUDE.md`).
  - *화면별 하드코딩 전면 치환은 범위 밖 — 해당 화면 손댈 때 점진 치환(신설 토큰 활용).*
- [x] **빈 상태 매력 보강 + 온보딩 다듬기** ✅ 구현·검증 완료 (2026-07-05) — 계획: [`.claude/plans/phase3-polish.md`](./.claude/plans/phase3-polish.md).
  - `EmptyState`에 선택적 CTA(`actionLabel`/`onAction`) 추가 → 홈 빈 상태에 "새 여행 만들기" 버튼(`_navigateToCreate` 연결).
  - 온보딩 deprecated `withOpacity` 6곳 → `withValues(alpha:)` 정리(시각 동일).
- [x] **지도 3곳 헤더 라벨링** ✅ 구현·검증 완료 (2026-07-05) — 공용 `widgets/map_header_pill.dart` 신설. 글로벌="내 여행 지도"(기존 pill 이식) / 여행="이 여행의 동선" / 커뮤니티="여행 경로"(닉네임 데이터 의존 회피). 정체성 부여로 "또 지도?" 인상 제거.
- [x] **글로벌 지도 탭 빈 상태 안내** ✅ 구현·검증 완료 (2026-07-05) — 핀 0개일 때 지도 위에 안내 카드("여행이 쌓일수록 나만의 세계 지도가 완성돼요") 오버레이. 독립 탭 유지 결정.
- [ ] **A-1 앱 브랜딩**(이름·아이콘) — 8단계에서 유일하게 남은 기능 미완 항목. **맨 마지막에 진행**(에셋·네이티브 설정 성격).

### Phase 4 — 초대 UX 개편 ✅ 구현·검증·커밋 완료 (2026-07-05)

> 배경: 기존 초대는 커스텀 스킴 링크(`tripmaptrace://…`)뿐이라 카톡에서 안 눌리고(=텍스트), 받는 사람이 코드를 수동 붙여넣어야 해 번거로웠다. 계획: [`.claude/plans/invite-ux-revamp.md`](./.claude/plans/invite-ux-revamp.md).
> 사용자 결정: ① 링크는 도메인 없이 지금 가능한 것만(https App Link는 배포 시점) ② 직접 초대는 **요청→수락** ③ 검색은 **닉네임 부분일치 + 이메일 정확일치**. 초대 역할 기본 VIEWER.

- [x] **A. 직접 초대 백엔드 신규 모듈 `invitation/`** (`8ad75c5`) — 요청→수락 플로우.
  - `V23__create_trip_invitations.sql`(status PENDING/ACCEPTED/DECLINED/CANCELED, `(trip_id, invitee_user_id) WHERE status='PENDING'` 부분 유니크). 엔티티/리포지토리/서비스/컨트롤러 + `UserRepository.searchByNicknameOrEmail`.
  - 엔드포인트: `GET /users/search?q=`, `POST /trips/{id}/invitations`(OWNER만), `GET /me/invitations`, `POST /invitations/{id}/accept|decline`. 검증: 비OWNER 403·자기자신 400·미존재 404·이미 멤버 409·중복 PENDING 409. 수락 시 `TripMember(VIEWER)` 저장 + `NotificationType.INVITE` + `FcmService.notifyInvitation`.
  - **런타임 11개 시나리오 실증**(검색/초대/중복/비OWNER/self/수락/이미멤버/재수락/거절) 전부 통과.
- [x] **B. 직접 초대 UI + 받은 초대 수락/거절** (`2c87da8`) — `flutter analyze` 0 error, test 4/4.
  - 모델 `UserSearchResult`·`ReceivedInvitation`, `api_service` 5개 메서드.
  - **보내기**(OWNER): `member_manage_screen`에 "사용자 초대" 버튼 → `InviteSearchSheet`(350ms 디바운스 검색 → 결과 리스트 → "초대").
  - **받기**: `home_tab` 상단에 받은 초대 카드 목록(있을 때만) — [수락][거절], 수락 시 목록 갱신.
- [x] **C. 초대 링크 시트 단순화 + 코드 복사** (`781b048`) — `invite_bottom_sheet` 재작성.
  - 진입 시 유효 토큰 자동 확보(만료/재발급 UI 제거), 죽은 스킴 공유 문구 → 참여 3단계 안내 + 초대 코드, 코드 복사 버튼 추가. QR은 대면 스캔용 딥링크 유지.
- [x] **D. 라디우스 하드코딩 토큰 치환** (`0ee3c53`) — `circular(8/12/16)`→`AppRadius.sm/md/lg`(15파일 41곳, 픽셀 무변경). Phase 3 "점진 치환" 방침 이행.
- [x] **딥링크/App Links 배포 준비 문서화** (`d3d310a`) — 계획: [`.claude/plans/deeplink-applinks-plan.md`](./.claude/plans/deeplink-applinks-plan.md) + `infra/deeplink/`에 `assetlinks.json`·Manifest 스니펫·폴백 페이지 템플릿. **라이브 코드 미변경**(배포 시 반영).
  - **범위 밖(배포 시점)**: https App Link + 도메인(카톡 클릭 근본해결, 미설치 스토어 폴백). 무료 서브도메인으로 무료 구현 가능.

### Phase 5 — 디자인 진단 반영 (Claude Design) ✅ 구현·정적검증 완료 (2026-07-12)

> 배경: Claude Design으로 실제 코드를 재현한 "배포 전 앱 디자인 검토"를 받았다. 톤(Pretendard+토큰)은 일관되나 **정보 위계·발견성**이 약한 4개 화면을 지적. 개선안은 새 색/폰트 없이 기존 토큰만 재배치. 4건 중 **위험 낮고 이득 명확한 3건만** 채택(순서: 홈카드 → 로그인 → 타임라인).

- [x] **홈 여행 카드 위계·가시성** (`home_tab.dart`)
  - info bar: 날짜·멤버·미디어 수가 전부 같은 12px 회색 → **멤버·미디어 수를 굵게(w700·textOnLight) 우측 정렬**, 날짜는 회색 보조로 좌측 유지. 스캔 시 시선 우선순위 부여.
  - 커버 사진 위 케밥 메뉴(`more_vert`)가 배경 없는 흰 아이콘 → **반투명 어두운 원형 배경(black38)** 추가로 밝은 사진 위에서도 보이게(실제 가시성 버그 해소).
- [x] **로그인 보조 링크 위계** (`login_screen.dart`)
  - 비번찾기·회원가입이 같은 회색 → **한 줄(spaceBetween)로 묶고 "회원가입"만 강조색(accent·bold)** 승격.
  - "로그인 없이 둘러보기"(별도 게스트 화면 진입점)를 흐린 텍스트 → **아웃라인 버튼(explore 아이콘)**으로 승격해 존재감 부여. 동작(`GuestCommunityScreen` 이동)은 그대로.
  - ※ 진단이 지적한 "Google 아이콘 네트워크 로딩" 이슈는 **실기기에서 정상 표시 확인 → 스킵**.
- [x] **타임라인 선택모드 액션 라벨링** (`timeline_tab.dart`)
  - 선택모드 상단에 라벨 없는 아이콘 4~5개(커버/다운로드/삭제/취소) 나열 + 툴팁은 터치에서 안 보임 → **커버지정·다운로드·삭제를 라벨 있는 하단 액션 바로 이동**(아이콘+글자, 삭제는 destructive 빨강). 상단엔 전체선택·닫기만 유지. **권한 분기 보존**(커버=OWNER·1개 선택, 다운로드/삭제=EDITOR↑, VIEWER는 바 숨김).
- [ ] ~~여행상세 상단 헤더(남색→흰색 통계 바 흡수)~~ — **보류.** 구조 변경이 가장 크고 이득은 주관적이며, "여행상세=다크 앱바" 표면 위계 결정(CLAUDE.md)과 얽힘. 필요 시 나중에 축소안으로.
- 검증: 수정 3파일 `flutter analyze` 신규 이슈 0 (login_screen의 기존 info 린트 외). 실기기 렌더 확인은 사용자 몫(정적 검증 방침).

---

## C. 우선순위 한 줄 요약

1. **지금 당장**: 댓글 API 권한 구멍 막기 (보안).
2. **그다음**: 미디어 뷰어·댓글 시트 통합 (중복 제거 = 체감 복잡도 감소).
3. **출시 직전**: 앱 브랜딩 + 마감 디테일 + (공개 배포 시) HTTPS/리프레시 토큰.
