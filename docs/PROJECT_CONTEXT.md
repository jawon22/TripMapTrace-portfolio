# TripMapTrace — 프로젝트 컨텍스트

## 🎯 프로젝트 목적

여행 중 촬영한 사진/영상을 **시간 + 위치 + 지도 기반**으로 시각화하는 공유형 기록 앱.

- Trip 단위로 미디어를 묶어 관리
- 타임라인(시간순) + 지도(경로) 두 가지 축으로 탐색
- 단순 갤러리가 아닌 "여행 경로 시각화 앱"

---

## 📦 Monorepo 구조

```
TripMapTrace/
 ├── app/                     Flutter 프론트엔드
 ├── backend/                 Spring Boot 백엔드
 ├── infra/                   Docker Compose (PostgreSQL + MinIO)
 ├── CLAUDE.md                Claude Code 가이드
 ├── docs/                    Claude 앱 Project와 공유 (민감 정보 금지)
 │    ├── PROJECT_CONTEXT.md  이 파일
 │    └── PLANNING.md / DESIGN.md / DECISIONS.md
 └── .claude/
      ├── server-private.md   서버 IP·SSH 키 (git 제외)
      └── plans/              단계별 구현 계획 문서
```

---

## 🧱 기술 스택

### Backend

- Spring Boot 3.5.10 / Java 17
- JPA (Hibernate) + Flyway
- PostgreSQL 16 (Docker)
- MinIO (Docker, S3 호환) — Presigned URL 업로드 방식
- S3 엔드포인트 분리
  - `internal`: `localhost:9000` (백엔드 HeadObject 검증용)
  - `external`: `10.0.2.2:9000` (Flutter Android 에뮬레이터 → 호스트 접근용)

### Frontend

- Flutter (Dart)
- `dio` — HTTP 클라이언트
- `image_picker` — 사진/영상 선택
- `permission_handler` — 권한 처리
- `exif` — EXIF 메타데이터 파싱 (GPS 좌표, 촬영 시각)
- `flutter_map` + CartoDB Voyager — 지도 라이브러리 (무료, API 키 불필요, 도로 색상 + 지명 포함)
- `latlong2` — 위경도 좌표 타입
- `video_thumbnail` — 영상 첫 프레임 추출 (클라이언트 사이드)
- `video_player` — 전체화면 영상 스트리밍 재생
- `gal` — 기기 갤러리에 사진/영상 저장
- `path_provider` — 임시 디렉터리 경로 조회
- `firebase_core` + `firebase_auth` — Firebase 초기화 (Google 로그인 기반)
- `google_sign_in` — Google OAuth (ID Token → 백엔드 검증)
- `kakao_flutter_sdk_user` — 카카오 OAuth (Access Token → 백엔드 검증)
- `flutter_secure_storage` — JWT 토큰 + 유저 정보 Android Keystore 암호화 저장

---

## 🔐 권한 모델

`TripMember` 기반 접근 제어:

| 기능            | OWNER | EDITOR | VIEWER |
| --------------- | :---: | :----: | :----: |
| 미디어 조회     |  ✅   |   ✅   |   ✅   |
| 미디어 업로드   |  ✅   |   ✅   |   ❌   |
| 미디어 다운로드 |  ✅   |   ✅   |   ❌   |
| 미디어 삭제     |  ✅   |   ✅   |   ❌   |
| 수동 위치 지정  |  ✅   |   ✅   |   ❌   |
| 초대 링크 생성  |  ✅   |   ❌   |   ❌   |
| 멤버 역할 변경  |  ✅   |   ❌   |   ❌   |
| 멤버 강제 삭제  |  ✅   |   ❌   |   ❌   |
| 본인 탈퇴       |  ❌   |   ✅   |   ✅   |
| Trip 수정/삭제  |  ✅   |   ❌   |   ❌   |

> 초대 토큰으로 참여 시 기본값은 `VIEWER`. OWNER가 `EDITOR`로 승급 가능.

---

## 🗄️ 데이터 모델

```
users
  └─< trip_members >─ trips
                           └─< media
                           └─< trip_likes      (커뮤니티 찜, V22)
                           └─< trip_comments   (커뮤니티 댓글, V22)
invite_tokens >─ trips
trip_invitations >─ trips, users   (직접 초대 요청→수락, V23)
notifications >─ users
holidays  (공휴일, 연 2회 배치 갱신)
```

**media 주요 필드:**

- `type`: `PHOTO | VIDEO`
- `status`: `UPLOADING | READY | FAILED`
- `taken_at`: 촬영 시각 (EXIF 기반, UTC)
- `lat / lng`: GPS 좌표 (nullable, `(0.0, 0.0)`도 null 처리)
- `address_text`: 역지오코딩 장소명 (업로드 시 Flutter가 채워 전달, nullable)
- `uploader_id`: 업로드한 유저 ID → `MediaResponse.uploaderNickname`으로 노출
- `storage_key`: MinIO 오브젝트 키
- `thumbnail_key`: 썸네일 키 (nullable)

---

## 🚀 개발 단계별 현황

### ✅ 1단계 — 핵심 인프라 & 업로드 파이프라인 (완료)

**Backend**

- [x] Trip 생성 / 내 Trip 목록 / 멤버 목록 API
- [x] 초대 토큰 발급 (`POST /api/v1/trips/{id}/invite`) — OWNER 전용, 7일 만료, 최대 10회
- [x] 초대 토큰 참여 (`POST /api/v1/invite/join`) — VIEWER 역할 부여
- [x] Presigned PUT URL 발급 (`POST /api/v1/trips/{id}/media/presign`)
- [x] S3 HEAD 검증 후 Media 저장 (`POST /api/v1/trips/{id}/media/complete`)
- [x] Media 목록 조회 + 인라인 presigned GET URL (`GET /api/v1/trips/{id}/media`)
- [x] 단건 download-url 발급 (`GET /api/v1/trips/{id}/media/download-url/{mediaId}`)

**Flutter**

- [x] 이미지 선택 (갤러리)
- [x] EXIF 파싱 (촬영 시각, GPS 좌표)
- [x] 3단계 업로드 플로우: presign → S3 PUT → complete
- [x] 기본 타임라인 탭 (미디어 카드 리스트, takenAt DESC 정렬)

---

### ✅ 2단계 — 지도 화면 & 경로 시각화 (완료)

> 앱의 핵심 가치인 "여행 경로 시각화"를 구현하는 단계.

**준비 작업 (완료)**

- [x] Flutter 파일 구조 분리 (`models/`, `services/`, `screens/`, `widgets/`)
- [x] `ApiService` 클래스로 API 호출 분리
- [x] Trip 목록 화면 (`TripListScreen`) — `tripId` 하드코딩 제거
- [x] Trip 상세 화면 (`TripDetailScreen`) — 업로드/타임라인/지도(플레이스홀더) 3탭
- [x] `flutter_map` + `latlong2` 패키지 추가

**Flutter — 지도 구현 (완료)**

- [x] 지도 탭에 `FlutterMap` 위젯 통합 (OSM 타일)
- [x] Trip별 GPS 좌표가 있는 미디어를 마커로 표시 (`MarkerLayer`)
- [x] 마커 탭 시 해당 미디어 이미지/정보 팝업 (`showModalBottomSheet`)
- [x] 촬영 순서(takenAt)대로 마커를 `Polyline`으로 연결 (경로 시각화)

**주의사항:**

- GPS 좌표가 없는 미디어(EXIF 없음)는 지도에 표시하지 않고 타임라인에만 노출
- `taken_at`이 없는 경우 업로드 시각(`created_at`)으로 fallback

---

### ✅ 3단계 — 썸네일 & 영상 처리 (완료)

> 구현 계획: `.claude/plans/3rd_plan.md` 참고

- [x] 이미지 업로드 완료 시 썸네일 자동 생성 — `Thumbnailator`로 400px 리사이즈, MinIO `thumbnails/` 경로 저장
- [x] 영상(mp4/mov) 업로드 지원 — Flutter `pickVideo()` 활성화, `type=VIDEO` 전달
- [x] 영상 썸네일 추출 — Flutter 클라이언트에서 `video_thumbnail` 패키지로 첫 프레임 추출 후 별도 S3 업로드, `thumbnailKey` 함께 전달 (FFmpeg 불필요)
- [x] `thumbnailUrl` presigned GET URL 응답 추가 (`MediaResponse`)
- [x] 지도 마커: `thumbnailUrl` 있으면 원형 이미지 마커, 없으면 원형 아이콘 마커 (스타일 통일)
- [x] 타임라인 카드: `thumbnailUrl` 우선 사용 (빠른 로딩)

**버그 수정 (2026-03-18):**

- [x] `ThumbnailService`: AWS SDK `getObject(Path)` → `getObjectAsBytes()` + `Files.write()` 교체 (`FileAlreadyExistsException` 수정)
- [x] `media_card.dart` / `map_tab.dart`: VIDEO + `thumbnailUrl` 없을 때 mp4 URL을 `Image.network()` 로드 방지, `Icons.videocam` 플레이스홀더로 대체
- [x] `upload_tab.dart`: VIDEO 업로드 완료 후 mp4 URL을 `Image.network()`로 표시하던 문제 수정, `Icons.videocam` 플레이스홀더로 대체

**추가 작업 (2026-03-18):**

- [x] Flutter 클라이언트 영상 썸네일 추출 — `video_thumbnail` 패키지, `_pickVideo()` 후 즉시 추출, S3 별도 업로드, `thumbnailKey` `/complete`에 전달
- [x] 백엔드: `MediaCompleteRequest`에 `thumbnailKey` 필드 복원, VIDEO 서버 비동기 처리(`ThumbnailService.generateVideoThumbnail`) 제거

---

### ✅ 3.5단계 — 지도 UX 개선 (완료)

- [x] GPS 없는 미디어도 지도에 표시 — `takenAt` 기준으로 가장 가까운 GPS 미디어 위치로 추정 배치
- [x] 추정 위치 미디어는 오렌지색 테두리로 시각 구분, 상세 시트에 "위치 추정 (GPS 없음)" 표시
- [x] 마커 디자인 통일 — `thumbnailUrl` 유무와 무관하게 모두 원형 카드 형태

---

### ✅ 3.6단계 — 타임라인 그리드 & 영상 재생 & 지도 스택 마커 (완료)

**타임라인 (`timeline_tab.dart`)**

- [x] 3열 그리드 (`GridView.builder`) — `takenAt ASC` 정렬, 영상 셀에 카메라 배지
- [x] 탭 → 전체화면 `PageView` 뷰어: 사진 핀치 줌(`InteractiveViewer`), 영상 실제 스트리밍 재생(`video_player`)
- [x] 영상 재생: 탭으로 재생/일시정지, 하단 스크럽바, `play_circle_outline` 오버레이
- [x] 롱프레스 → 선택 모드, 체크박스 UI, "전체 선택" 지원
- [x] 선택 항목 다운로드 → 기기 갤러리 저장 (`gal` 패키지)

**지도 (`map_tab.dart`)**

- [x] 같은 위치 미디어 그룹화 → 스택 마커 (최대 3장 대각선 겹침)
- [x] 겹침 방향: primary(GPS 최초) 좌하단 맨 앞, 나머지 우상단으로 순서대로 보임
- [x] 마커 클릭 → 하단 패널에 해당 위치 미디어 전체 가로 스크롤
- [x] 마커/패널 썸네일: `thumbnailUrl` → `downloadUrl`(사진 폴백) → 아이콘
- [x] 마커 테두리 제거 (그림자만 유지)
- [x] 정렬 버그 수정: primary = 가장 이른 GPS 1개, 나머지는 타입 무관 `takenAt ASC`

**Android 설정**

- [x] `res/xml/network_security_config.xml` 추가 — ExoPlayer의 `10.0.2.2` HTTP 스트리밍 허용

---

### ✅ 4단계 — 인증 (JWT) (완료)

> 구현 계획: `.claude/plans/4th_plan.md` 참고. 구현 완료: 2026-03-22

**Backend**

- [x] `User` 엔티티 + `UserRepository` 추가
- [x] `JwtUtils` — 토큰 발급/검증 (7일 만료, 환경변수 `JWT_SECRET`)
- [x] `JwtAuthenticationFilter` — Bearer 토큰 검증 필터
- [x] `SecurityConfig` — `/api/v1/auth/**` 공개, 나머지 인증 필요
- [x] `POST /api/v1/auth/register` — 회원가입 (BCrypt 암호화)
- [x] `POST /api/v1/auth/login` — 로그인 후 JWT 발급
- [x] 모든 컨트롤러 `DEV_USER_ID` 제거 → `SecurityContext` 추출
- [x] V7 마이그레이션 — dev 유저 BCrypt 해시로 교체
- [x] V8 마이그레이션 — users 시퀀스 수정
- [x] 모든 엔티티 `@CreationTimestamp` 적용 (Trip, TripMember, Media, InviteToken, User)

**Flutter**

- [x] `flutter_secure_storage` — Android Keystore 암호화 저장
- [x] `AuthService` — 토큰 저장/로드/삭제
- [x] `ApiService` Dio 인터셉터 — `Authorization` 헤더 자동 첨부
- [x] `LoginScreen` — 로그인/회원가입 전환 단일 화면
- [x] `main.dart` — 토큰 유무로 첫 화면 분기
- [x] `TripListScreen` AppBar 로그아웃 버튼 — 토큰 삭제 후 `LoginScreen`으로 스택 교체

---

### ✅ 5단계 — 보완 기능 (완료)

> 구현 계획: `.claude/plans/5th_plan.md` 참고. 구현 완료: 2026-03-22

**Backend**

- [x] `SecurityConfig` — `/error` 경로 permitAll 추가 (500 에러가 401로 오인되던 버그 수정)
- [x] `application.properties` — `server.error.include-message=always` 추가
- [x] Trip 수정 (`PATCH /api/v1/trips/{tripId}`) / 삭제 (`DELETE`) — OWNER 전용, S3 오브젝트 연쇄 삭제
- [x] 멤버 역할 변경 (`PATCH /api/v1/trips/{tripId}/members/{memberId}/role`) — OWNER 전용
- [x] 멤버 강제 삭제 (`DELETE /api/v1/trips/{tripId}/members/{memberId}`) — OWNER 전용
- [x] 본인 탈퇴 (`DELETE /api/v1/trips/{tripId}/members/me`) — OWNER 불가
- [x] Media 삭제 (`DELETE /api/v1/trips/{tripId}/media/{mediaId}`) — EDITOR 이상, S3 + DB 동시 제거
- [x] 수동 위치 지정 (`PATCH /api/v1/trips/{tripId}/media/{mediaId}/location`) — EDITOR 이상
- [x] Trip 목록 조회 — `createdBy` 기준 → `TripMember` 기준으로 변경 (초대 참여 Trip 포함)
- [x] `TripResponse`에 `myRole` 필드 추가
- [x] `MediaService` — `(0.0, 0.0)` 좌표 업로드 시 null로 저장
- [x] VIEWER 다운로드 차단 (`download-url` API 403 반환)

**Flutter**

- [x] `GlobalKey<NavigatorState>` + Dio 인터셉터 — 401 수신 시 자동 로그인 화면 이동
- [x] `TripListScreen` — FAB 바텀시트 (새 여행 만들기 / 초대 코드로 참여), OWNER 팝업 메뉴 (수정/삭제)
- [x] `TripDetailScreen` — myRole 기반 탭 구성 (VIEWER: 2탭, EDITOR/OWNER: 3탭), 멤버 관리 버튼
- [x] `MemberManageScreen` (신규) — 멤버 목록, 역할 뱃지, 역할 변경/삭제/초대코드 생성/탈퇴
- [x] `TimelineTab` — VIEWER 다운로드 버튼 숨김, EDITOR 이상 삭제 버튼
- [x] `MapTab` — 수동 위치 지정 모드 (롱프레스), VIEWER 위치 지정 버튼 숨김
- [x] `map_tab.dart` — `(0.0, 0.0)` 좌표 GPS 없음으로 처리

---

### ✅ 6단계 — 디자인 폴리싱 (완료)

> 구현 계획: `.claude/plans/6th_plan.md`, 상세: `.claude/plans/6_detail_plan.md`. 완료: 2026-03-31

- [x] Phase 1 — 네비게이션 구조 변경 (MainScreen + BottomNav)
- [x] Phase 2 — 신규 기능 구현 (nickname, ProfileTab, GlobalMapTab, 다중업로드)
- [x] Phase 2-5 — 코드 품질 수정 (S3Helper 추출, 중복 제거)
- [x] Phase 3 — ThemeData 전역 적용 (Pretendard, AppColors, AppTheme)
- [x] Phase 4 — 화면별 디자인 수정 (Login/Home/Detail/Timeline/Map/Upload/Member 전체)
- [x] Phase 5 — 공통 UX 개선 (로딩 amber, SnackBar 통일, Empty State 통일, 다이얼로그 버튼 레이아웃)

---

### 🔲 7단계 — 배포 준비 + 핵심 기능 추가

> 구현 계획: **`7th_plan_1.md`(Phase 1~5) + `7th_plan_2.md`(Phase 6~9)** 두 파일을 모두 확인할 것.
> Phase 구성표 및 진행 순서는 `7th_plan_1.md` 상단에 있음.

- [x] 글로벌 지도 클러스터링 + 역지오코딩 (GPS → 지역명 변환) ← Phase 1 완료 (2026-04-01)
- [x] 딥링크 + QR 코드 초대 + 초대 코드 만료 상태/재발급 ← Phase 2 완료 (2026-04-02)
- [x] 여행 통계 + 타임라인 필터(사진/영상) + 여행 커버 이미지 직접 지정 ← Phase 6 완료 (2026-04-03)
- [x] 소셜 로그인 (구글 / 카카오 OAuth) ← Phase 3 완료 (2026-04-04)
  - `users` 테이블에 `provider`, `provider_id`, `profile_image_url` 컬럼 추가
  - Flutter 네이티브 SDK (`google_sign_in`, `kakao_flutter_sdk_user`)
  - 프로필 탭 소셜 프로필 이미지 자동 표시
  - Apple 로그인 — 보류 (Mac + Xcode + Apple Developer Program $99 필요)
- [x] 프로필 사진 업로드 & 닉네임 수정 & 계정관리 화면 ← Phase 4 완료 (2026-04-06)
  - S3 presigned PUT 방식 아바타 업로드 (`avatars/{userId}/{uuid}.ext`)
  - `AccountSettingsScreen` 신규 (닉네임 수정 + Phase 7 placeholder)
  - 멤버관리 화면 닉네임 + 프로필 이미지 표시 (`TripMemberResponse` 확장)
- [x] 멤버 업로드 알림 (FCM) + 알림 설정 ON/OFF ← Phase 5 구현 완료 (2026-04-09), **테스트 미완료**
  - `FcmConfig` + `FcmService` (Firebase Admin SDK, graceful disable 지원)
  - 알림 발송: 업로드 / 멤버 참여·탈퇴·강퇴 / 역할 변경 / 여행 삭제
  - `users` 테이블 `fcm_token`, `notify_upload`, `notify_join`, `notify_role_change` 컬럼 추가 (V12)
  - `AccountSettingsScreen` 알림 설정 섹션 (3가지 토글)
  - 테스트 가이드: `.claude/plans/PHASE5_TEST_GUIDE.md` (10개 TC, 기기 2대 이상 필요)
- [x] 비밀번호 재설정 (이메일 발송) ← Phase 7-1 완료 (2026-04-19)
  - Gmail SMTP (`spring-boot-starter-mail`) 연동, `.env`에 `MAIL_USERNAME` / `MAIL_PASSWORD` 등록
  - `V13__add_password_reset_tokens.sql` — `password_reset_tokens` 테이블 (UUID 토큰, 30분 만료)
  - `PasswordResetToken` 엔티티 + `PasswordResetTokenRepository`
  - `EmailService` — HTML 포맷 재설정 메일 발송 (딥링크 버튼 포함)
  - `POST /api/v1/auth/password/reset-request` — 이메일 입력 → 토큰 생성 + 메일 발송 (소셜 유저 무시, 항상 200 응답)
  - `POST /api/v1/auth/password/reset` — 토큰 검증 + 새 비밀번호 저장
  - `User.updatePasswordHash()` 메서드 추가
  - Flutter: `login_screen.dart` "비밀번호를 잊으셨나요?" 링크 + `_PasswordResetDialog` (별도 StatefulWidget)
  - Flutter: `reset_password_screen.dart` 신규 (새 비밀번호 입력 화면)
  - Flutter: `main.dart` `tripmaptrace://reset-password?token=...` 딥링크 분기 추가
  - Flutter: `AndroidManifest.xml` `reset-password` host intent-filter 추가
- [x] 비밀번호 변경 (로그인 상태, 이메일 유저 전용) ← Phase 7 완료 (2026-04-20)
- [x] 계정 탈퇴 (2단계 확인 플로우, 전체 유저) ← Phase 7 완료 (2026-04-20)
- [ ] HTTPS 적용 (Cloudflare Tunnel) ← Phase 9 (도메인 구매 시)
- [x] 프로덕션 환경 Docker Compose / 클라우드 배포 설정 ← Phase 8 진행 중 (2026-04-23, E2E 테스트 남음)

---

### 🔲 8단계 — UI/UX 개선 및 기능 확장 (진행 중)

> 세부 계획: `.claude/plans/8th_plan.md` 참고.

**버그 수정 완료 (2026-05-03)**
- [x] 소셜 로그인 계정 선택 — Google `signOut` 강제, 카카오 선택 다이얼로그 추가
- [x] 커버 이미지 홈탭/지도탭 불일치 — `setCover` save 누락 수정 + `buildCoverUrl` 통일
- [x] 이미지 업로드 OOM — `Throwable` catch + JVM 힙 512m 상향

**Phase A 진행 중 (2026-05-03)**
- [x] A-2: 회원가입 화면 분리 (`signup_screen.dart` 신규, 약관 동의 포함)
- [x] A-2: 로그인 화면 개선 (로고 복원, 회원가입 탭 분리, LoginScreen을 앱 진입점으로)
- [x] A-2: 회원가입 후 자동 로그인
- [x] A-3: 약관 동의 UI (전체동의 + ExpansionTile 드롭다운 — 필수 4개, 선택 2개)
- [ ] A-1: 앱 브랜딩 (이름/아이콘) — 이름 확정 후 진행
- [x] A-3: Backend — `push_agreed`, `marketing_agreed` 컬럼 추가 (V15)
- [x] A-4: 온보딩 화면 (`onboarding_screen.dart`, 3장 스와이프, 서버+로컬 완료 여부 저장)
**Phase B 완료 (2026-05-05)**
- [x] B-3: 지도 타일 CartoDB Voyager 교체 (`map_tab.dart`, `global_map_tab.dart`)
- [x] B-3: 마커 디자인 개선 (흰 테두리 + 그림자 강화), 폴리라인 4px, 빈 상태 분리
- [x] B-3: 글로벌 지도 — "N개 지역" 탭 시 지역 목록 바텀시트 + 지도 이동
- [x] B-3: 글로벌 지도 — 탭 전환 시 줌/위치 자동 초기화
- [x] B-4: 타임라인 풀스크린 뷰어 (`_FullscreenViewer`) — 이미 구현 확인, `photo_view` 패키지 불필요 (`InteractiveViewer` + `PageView` + `VideoPlayer`로 충분)
- [x] B-4: 풀스크린 뷰어 상단에 업로더 닉네임 + 역지오코딩 장소명 표시
- [x] 미디어 `address_text` 업로드 시 실제 저장 — PHOTO 업로드 시 `GeocodingService.reverseGeocode()` 호출 후 `completeUpload`에 전달 (기존엔 항상 null)
- [x] `MediaResponse`에 `uploaderNickname` 필드 추가 — `MediaService.list()`에서 batch 조회, `complete()`·`updateLocation()`은 단건 조회
- [x] 지도 상세 패널 — GPS 좌표 + 장소명 두 줄 → "장소명 (위도, 경도)" 한 줄로 통합
- [x] B-1: 여행 생성 — 다이얼로그 → `create_trip_screen.dart` 단일 화면 (이름 입력 후 달력 표시)
- [x] B-1: 한국 공휴일 달력 — 공공데이터포털 API → 백엔드 배치(`@Scheduled` 연 2회) → DB 저장 → Flutter 180일 캐시
- [x] B-1: 만들기 완료 후 여행 상세로 직행 (`pushReplacement`, 기존엔 목록에서 탭해야 이동)
- [x] B-1: 달력 헤더 "오늘" 버튼 — 현재 월로 즉시 이동, 년/월 피커는 단순화 결정으로 제외
- [x] B-2: 여행 카드 기간 표시 개선 — 시작=종료면 하루 표시, endDate 있으면 "시작 ~ 종료" 형식 (AppBar 닉네임/아바타·빈 상태 일러스트는 불필요 판단으로 제외)
- [x] B-5: 프로필 화면 개선 — 통계 카드 "참여 그룹" 제거, 참여 중인 여행 섹션(최근 3개, 역할 뱃지, 탭→상세, 전체 보기→홈탭)
**Phase C 진행 중 (2026-05-07)**
- [x] C-1: 나의 미디어 갤러리 — 프로필 미디어 탭 바텀시트, 3열 그리드, 풀스크린 뷰어 여행명 표시
- [x] C-2: 좋아요 — `media_likes` 테이블(V18), 토글 API, 타임라인/풀스크린 하트 + scale 애니메이션
- [x] C-3: 댓글 — `comments` 테이블(V19), CRUD API, 풀스크린 뷰어 댓글 바텀시트, 타임라인 그리드 댓글 수 표시
- [~] C-4: 멤버 태그 — 취소 (닫힌 여행 공간에서 실용성 낮음)
- [x] UX 개선 패치 7건 완료 (2026-05-09) — 세부 내역: `.claude/plans/8th_plan.md` "실기기 테스트 UX 개선 패치" 섹션 참고
  - 달력 오늘 날짜 강조 조건, 지도 탭 재탭 리셋, 업로드 후 통계 자동 갱신
  - 지도 탭 → 풀스크린 진입, 거리 통계 제거, 프로필 탭 자동 새로고침, 닉네임 숨김
- [x] C-5: 알림 히스토리 + FCM 실동작 완료 (2026-05-12) — 세부 내역: `.claude/plans/8th_plan.md` "C-5" 섹션 참고
  - `notifications` 테이블(V20), NotificationService/Controller, 알림 API 4개
  - FcmService 기존 6종 트리거 DB 저장 연결, 좋아요·댓글 알림 신규 추가
  - Flutter 벨 아이콘 + 미읽음 뱃지 + 알림 목록 화면 (`notification_screen.dart`)
- [x] 알림 화면 UX 개선 패치 2건 완료 (2026-05-14)
  - UX-8: 알림 스와이프 삭제 — `Dismissible` + `DELETE /api/v1/notifications/{id}`
  - UX-9: 벨 아이콘 HomeTab·ProfileTab AppBar로 이동, MainScreen AppBar 제거
- [x] D-1: 여행 공개/비공개 토글 (OWNER) ← 완료 (2026-05-17)
  - V21: `trips.is_public BOOLEAN DEFAULT false`
  - `PATCH /api/v1/trips/{tripId}/visibility` — OWNER 전용
  - Flutter `home_tab.dart` OWNER 팝업 메뉴 토글
- [x] D-2: 커뮤니티 피드 탭 완료 (2026-05-17)
  - V22: trip_likes, trip_comments 테이블
  - GET /api/v1/community/trips (목록, 정렬/검색/필터)
  - GET /api/v1/community/trips/{tripId} (상세, 미디어+경로+최근댓글)
  - POST /api/v1/community/trips/{tripId}/like (좋아요 토글)
  - 하단 탭 3개 → 4개, community_tab.dart 신규
- [x] D-3: 커뮤니티 댓글 CRUD 완료 (2026-05-17)
  - POST/PATCH/DELETE /api/v1/community/trips/{tripId}/comments
  - Flutter 전체 댓글 바텀시트 (목록 + 작성 + 본인 수정/삭제)
- [x] D-4: 게스트 둘러보기 완료 (2026-05-21)
  - GET /api/v1/community/** permitAll (비로그인 조회 가능)
  - 로그인 화면 "로그인 없이 둘러보기" 버튼 → GuestCommunityScreen
  - 좋아요/댓글 시도 시 로그인 유도 다이얼로그
  - 피드 풀-투-리프레시 + 좋아요/댓글 카드↔시트 실시간 동기화 수정
- [x] 커뮤니티 경로 지도 개선 완료 (2026-05-21)
  - 지도 제스처 비활성화 → PageView 좌우 스와이프 복원
  - 진입 시 전체 경로 bounds 자동 맞춤 (CameraFit.bounds)
  - 이전/다음 버튼 — GPS 포인트 시간순 탐색, 지도 이동
  - 현재 포인트 썸네일 + 일자(N일차) + 시각 표시 하단 패널
  - 전체 경로 보기 버튼(⛶) 추가

---

### ✅ 출시 진단 정리 (APP_REVIEW Phase 1~3, 완료 2026-06~07)

> 종합 진단 + 로드맵: 루트 `APP_REVIEW.md`. 계획: `.claude/plans/phase1-security.md`, `.claude/plans/phase2-viewer.md`, `.claude/plans/phase3-design-tokens.md` 등.

- [x] **Phase 1 — 보안/정합성**: 댓글 API 권한 구멍(IDOR) 보강(`CommentService` 멤버체크), 미디어 댓글 수정 허용 통일, 글로벌 예외 핸들러(`GlobalExceptionHandler`, IllegalState/Argument→400), `MediaService` awsErrorDetails null-safe.
- [x] **Phase 2 — 뷰어 통합**: `FullscreenViewer`를 `widgets/`로 이동해 4화면 공유, 커뮤니티 `_FullscreenGallery` 흡수(영상 깨짐 버그 동시 해결), 풀스크린 단건 다운로드.
- [x] **Phase 3 — 디자인 토큰/마감**: `AppColors` success/warning/info + `app_spacing/radius/text_styles` 토큰, 성공 SnackBar 초록, 빈 상태 CTA, 지도 3곳 헤더 라벨(`map_header_pill`), 글로벌 지도 빈 상태 안내.

### ✅ 초대 UX 개편 + 딥링크(App Links) (완료 2026-07-05)

> 계획: `.claude/plans/invite-ux-revamp.md`, `.claude/plans/deeplink-applinks-plan.md`. 진단: `APP_REVIEW.md` Phase 4.

**직접 초대(요청→수락) — 신규 백엔드 모듈 `invitation/`**
- V23: `trip_invitations`(status PENDING/ACCEPTED/DECLINED/CANCELED, `(trip_id, invitee_user_id)` PENDING 부분 유니크)
- `GET /users/search?q=`(닉네임 부분일치 + 이메일 정확일치), `POST /trips/{id}/invitations`(OWNER 전용), `GET /me/invitations`, `POST /invitations/{id}/accept|decline`
- 수락 시 `TripMember(VIEWER)` 저장 + `NotificationType.INVITE` + `FcmService.notifyInvitation`

**직접 초대 UI + 받은 초대 처리 (Flutter)**
- 모델 `UserSearchResult`·`ReceivedInvitation`, `InviteSearchSheet`(디바운스 검색→초대)
- `member_manage_screen` "사용자 초대" 버튼, `home_tab` 상단 받은 초대 카드([수락][거절])

**초대 링크 시트 단순화** (`invite_bottom_sheet.dart`)
- 진입 시 유효 토큰 자동 확보(만료/재발급 UI 제거), 공유 문구 참여 안내 + 코드, 코드 복사 버튼

**딥링크 App Links (카톡 링크 클릭)**
- 정적 호스팅: **Netlify `tripmaptrace.netlify.app`** — `/.well-known/assetlinks.json`(debug 키 SHA-256) + `/invite/*` 폴백 페이지. 소스: `infra/deeplink/site/` (드래그 배포)
- `config/app_links.dart` 호스트 단일 출처, `invite_bottom_sheet` QR·공유 https 전환, `main.dart` https 딥링크 수신, `AndroidManifest` https intent-filter(`autoVerify`)
- 커스텀 스킴(`tripmaptrace://`)은 **유지**(QR 대면 스캔·구버전 호환) — 비파괴
- 라디우스 하드코딩 `circular(8/12/16)`→`AppRadius.sm/md/lg`(15파일) 토큰 치환 병행
- ⚠️ **남은 검증**: 앱 재빌드 + **재설치** 후 실기기 확인(App Links 검증은 설치 시점에 걸림). 미설치자 스토어 폴백은 Play Store 출시 후.

---

### 🔲 7단계 미완료 항목 (별도 조건 필요)

> `7th_plan_2.md` 참고.

| 항목 | 조건 | 비고 |
|------|------|------|
| `ios/Runner/Info.plist` ATS 예외 추가 | Mac 필요 | Mac 생길 때 진행 |
| Phase 9 — HTTPS (Cloudflare Tunnel) | 도메인 구매 (~$10/년) | 공개 배포 시 진행 |
| FCM 알림 Group 2~3 테스트 | 기기 2대 필요 | 기능 구현은 완료, 테스트만 미완 |
| Play Store / App Store 등록 | HTTPS + 심사 | Phase 9 이후 |

---

## ⚠️ 현재 알려진 기술 부채

| 항목 | 위치 | 처리 시점 |
|------|------|------|
| 리프레시 토큰 미구현 | `JwtUtils` | App Store 배포 전 |
| HTTPS 미적용 | 전체 | Phase 9 (도메인 구매 시) |
| iOS ATS 예외 미적용 | `ios/Runner/Info.plist` | Mac 생길 때 |
| JVM 힙 512m 한계 (대용량 썸네일 처리) | `docker-compose.prod.yml` | ARM VM 마이그레이션 시 근본 해결 |

---

## 📌 다음 작업 시 시작점

**APP_REVIEW Phase 1~4 완료** — 초대 UX 개편 + App Links까지 반영됨. 남은 개발은 사실상 앱 브랜딩뿐.

**현재 서버 상태 (2026-07-05 재배포 완료)**
- Oracle Cloud VM — IP·포트·SSH 키 경로는 `.claude/server-private.md` 참고 (git 제외, 공유 금지)
- JVM 힙: `-Xms128m -Xmx512m`, 스왑 2GB
- ✅ **초대 UX 백엔드(V23 invitation 모듈) Oracle 배포 완료** (2026-07-05) — `flyway V23 success`, `trip_invitations` 생성, `/me/invitations`·`/users/search` 서빙(401) 확인.
- 최신 APK: `app-release.apk` (64.9MB) — App Links + 직접 초대 + `BASE_URL=<서버 주소>`. **폰 재설치 필요**(App Links 반영).

**딥링크 정적 사이트 (2026-07-05)**
- Netlify: `https://tripmaptrace.netlify.app` (App Links assetlinks + `/invite` 폴백). 소스 `infra/deeplink/site/`, 변경 시 폴더 재드래그 배포.
- assetlinks 지문 = **debug 키** SHA-256. 정식 릴리스 keystore 만들면 지문 교체 필요.

**재배포 / APK 빌드 명령어**: `7th_plan_2.md` Phase 8 "서버 재배포 절차" 참고.
- APK: `flutter build apk --release --dart-define=BASE_URL=http://<서버IP>:<포트>` (실제 값은 `.claude/server-private.md`)
- ⚠️ App Links 반영은 **재빌드 후 폰 재설치** 필요(설치 시점 검증).

**다음 작업 후보**:
1. App Links 실기기 검증(APK 재빌드+재설치 → 카톡 링크 클릭 테스트) ← 진행 중
2. A-1 앱 브랜딩(이름/아이콘) — 기능상 유일하게 남은 항목, "출시 직전" 예정
3. (공개 배포 시) 백엔드 HTTPS + 리프레시 토큰 + Play Store
> 출시 관점 종합 진단 로드맵: 루트 [`APP_REVIEW.md`](../APP_REVIEW.md). Phase 1~4 완료 반영됨.

**기타 참고**
- Windows 포트 5432 예약 문제: `net stop winnat` → Docker 시작 → `net start winnat` 로 해결 (근본 해결: 관리자 권한으로 `netsh int ipv4 add excludedportrange protocol=tcp startport=5432 numberofports=1` 실행)
- Android APK 빌드: 위 "재배포 / APK 빌드 명령어" 참고
- Kotlin 버전 경고 (2.0.21 → 2.1.0 권장): 당장 급하지 않음, Flutter 버전 업 시 함께 처리
