# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **현재 진행 상황은 [`docs/PROJECT_CONTEXT.md`](./docs/PROJECT_CONTEXT.md)를 먼저 읽을 것.** 완료된 단계, 다음 작업, 알려진 기술 부채가 모두 기록되어 있음.
>
> **기획·디자인·확정된 결정은 [`docs/`](./docs/)를 확인할 것.** `PLANNING.md`(기획), `DESIGN.md`(디자인), `DECISIONS.md`(결정 기록). 작업 중 새로 확정된 결정은 `DECISIONS.md`에 추가한다.
>
> **`docs/`는 Claude 앱 Project와 연결된 공유 폴더다.** 서버 IP·포트·SSH 키 경로·비밀번호 등 민감 정보는 `docs/`에 절대 쓰지 말고 `.claude/server-private.md`(git 제외)에만 기록한다. 서버 접속이 필요한 작업은 이 파일을 참고한다.

## Project Overview

**TripMapTrace** is a travel media sharing app. Users create trips, invite members, and upload geotagged photos/videos. The app extracts EXIF metadata (GPS coordinates, timestamp) from images and displays them in a timeline.

Stack:
- **Frontend**: Flutter (Dart) — `app/`
- **Backend**: Spring Boot 3.5 / Java 17 — `backend/`
- **Storage**: MinIO (S3-compatible, local dev) — presigned URLs via AWS SDK v2
- **DB**: PostgreSQL 16 + Flyway migrations
- **Infra**: Docker Compose — `infra/docker-compose.yml`

---

## Commands

### Start local infrastructure
```bash
cd infra
docker compose up -d
```
Starts PostgreSQL (port 5432) and MinIO (API: 9000, Console: 9001).
MinIO bucket `tripmaptrace-media` must be created manually via the console at `http://localhost:9001` (user: `minioadmin` / `minioadmin123`).

### Backend (Spring Boot)
```bash
cd backend
# $env:JWT_SECRET=
./gradlew bootRun          # run
./gradlew build            # compile + test
./gradlew test             # tests only
./gradlew test --tests "tripmaps.backend.SomeTest"  # single test
```

### Flutter app
```bash
cd app
flutter pub get            # install dependencies
flutter run                # run on connected device/emulator
flutter test               # all tests
flutter test test/widget_test.dart  # single test file
```

---

## Architecture

### Media Upload Flow (core feature)
1. Flutter picks image → reads EXIF (GPS lat/lng + `DateTimeOriginal`)
2. `POST /api/v1/trips/{tripId}/media/presign` → backend returns a 10-min presigned PUT URL and a `storageKey`
3. Flutter PUTs the raw bytes directly to MinIO using the presigned URL
4. `POST /api/v1/trips/{tripId}/media/complete` → backend does a `HeadObject` on S3 to verify the file exists and validate its `Content-Type`, then saves a `media` row with status `READY`
5. List API (`GET /api/v1/trips/{tripId}/media`) returns each item with an inline presigned GET URL (10-min TTL) as `downloadUrl`

### S3 Dual-Endpoint Design
`S3Config` creates **two separate beans**:
- `S3Client` uses `app.s3.endpoint-internal` (`localhost:9000`) — used by the backend for `HeadObject` verification
- `S3Presigner` uses `app.s3.endpoint-external` (`10.0.2.2:9000`) — used to generate presigned URLs that are accessible from the Android emulator

When changing the presigned URL host, edit `app.s3.endpoint-external` in `application.properties`.

### Backend Module Structure
Each feature is a self-contained package under `tripmaps.backend.<feature>/`:
```
<feature>/
  api/          ← @RestController + DTO records
  domain/       ← @Entity classes + enums
  repository/   ← Spring Data JPA interfaces
  service/      ← @Service (business logic, S3 calls)
```
DTOs are Java `record` types. Entities use Lombok. No MapStruct — manual mapping in `toResponse()` methods inside services.

현재 모듈 목록:
- `trip/` — Trip CRUD, TripMember 관리, 통계, 커버 이미지, 지도 핀
- `media/` — 미디어 업로드/조회/삭제, 좋아요(`MediaLike`), 댓글(`Comment`), 썸네일
- `invite/` — 초대 토큰 발급/참여/상태 조회
- `auth/` — 이메일 회원가입/로그인, 소셜 OAuth, 비밀번호 재설정
- `user/` — 프로필 조회/수정, 아바타 업로드, FCM 토큰, 알림 설정, 계정 탈퇴
- `holiday/` — 공휴일 배치 수집(`@Scheduled` 연 2회), 조회 API
- `notification/` — 앱 내 알림 히스토리 저장/조회 (FCM과 별도 DB 레코드)
- `fcm/` — `FcmService` (Firebase Admin SDK, 업로드/참여/역할 변경/여행 삭제 이벤트 발송)
- `config/` — `S3Config`, `S3Helper`, `SecurityConfig`, `JwtUtils`, `JwtAuthenticationFilter`, `FcmConfig`

### Authentication
JWT 기반 인증 구현 완료.
- `JwtUtils` — 토큰 발급/검증 (7일 만료, 환경변수 `JWT_SECRET` 필수)
- `JwtAuthenticationFilter` — Bearer 토큰 검증 필터 (모든 요청)
- `SecurityConfig` — `/api/v1/auth/**`, `/api/v1/oauth/**`, `/error` 공개, 나머지 인증 필요
- 소셜 로그인: Google (`GoogleTokenVerifier`), 카카오 (`KakaoTokenVerifier`) OAuth 지원
- 비밀번호 재설정: Gmail SMTP 이메일 발송, `password_reset_tokens` 테이블, 30분 만료 UUID 토큰

### Role System
`TripRole`: `OWNER` > `EDITOR` > `VIEWER`.
- `OWNER`만 초대 토큰 생성, 멤버 역할 변경/강퇴, Trip 수정/삭제 가능.
- `EDITOR`는 미디어 업로드/삭제, 수동 위치 지정, 본인 탈퇴 가능.
- `VIEWER`는 조회만 가능 (업로드/다운로드/삭제 불가).
- 초대 토큰 참여 시 기본값 `VIEWER`. 토큰은 7일 만료, 최대 10회 사용.

### Database Migrations
Flyway migrations live in `backend/src/main/resources/db/migration/`. JPA is set to `ddl-auto=validate` — schema changes must go through a new `V{n}__description.sql` file.

### Flutter App Structure

```
app/lib/
  main.dart                        ← 앱 진입점: 토큰 유무 + 온보딩 여부로 첫 화면 분기
  theme/
    app_colors.dart                ← 앱 전역 색상 상수 (시맨틱 + 상태색 success/warning/info/border)
    app_spacing.dart               ← 간격 토큰 (xs4/sm8/md12/lg16/xl24)
    app_radius.dart                ← 모서리 반경 토큰 (sm8/md12/lg16)
    app_text_styles.dart           ← 타이포 토큰 (h1/h2/title/body/caption, Pretendard)
    app_theme.dart                 ← ThemeData (Pretendard 폰트, 전역 스타일, 토큰 참조)
  models/
    trip.dart                      ← Trip 모델
    media_item.dart                ← MediaItem 모델 (thumbnailUrl, uploaderNickname 포함)
    user_stats.dart                ← 유저 통계 모델
    trip_stats.dart                ← 여행 통계 모델
    trip_map_pin.dart              ← 글로벌 지도 핀 모델
    comment_item.dart              ← 댓글 모델
  services/
    api_service.dart               ← Dio 기반 API 클라이언트 (전체 API), 401 시 자동 로그인 이동
    auth_service.dart              ← JWT 토큰 저장/로드/삭제 (flutter_secure_storage)
    geocoding_service.dart         ← 역지오코딩 (GPS → 장소명)
    holiday_service.dart           ← 공휴일 조회 + 180일 클라이언트 캐시
  screens/
    login_screen.dart              ← 로그인 화면 (이메일/소셜), 비밀번호 재설정 다이얼로그
    signup_screen.dart             ← 회원가입 화면 (약관 동의 포함)
    onboarding_screen.dart         ← 온보딩 (3장 스와이프, 최초 1회)
    main_screen.dart               ← BottomNavigationBar 컨테이너 (4탭)
    home_tab.dart                  ← 홈탭: 여행 목록, FAB (새 여행 / 초대 참여)
    global_map_tab.dart            ← 글로벌 지도탭: 전체 여행 핀 클러스터링, 지역 목록
    create_trip_screen.dart        ← 여행 생성 전용 화면 (이름 입력 + 공휴일 달력)
    trip_detail_screen.dart        ← 여행 상세: myRole 기반 탭 구성
    upload_tab.dart                ← 다중 이미지/영상 선택, EXIF 파싱, 3단계 업로드
    timeline_tab.dart              ← 3열 그리드, 좋아요/댓글/선택 다운로드, 풀스크린 뷰어
    map_tab.dart                   ← 여행 지도: 폴리라인 + 그룹 마커 + 수동 위치 지정
    profile_tab.dart               ← 프로필: 통계, 참여 중인 여행, 나의 미디어 갤러리
    member_manage_screen.dart      ← 멤버 관리: 역할 변경, 강퇴, 초대 코드 생성
    account_settings_screen.dart   ← 계정 설정: 닉네임 수정, 알림 설정, 비번 변경, 탈퇴
    reset_password_screen.dart     ← 비밀번호 재설정 (딥링크 진입)
  widgets/
    media_card.dart                ← 미디어 카드 위젯
    app_snackbar.dart              ← 공통 SnackBar 헬퍼
    empty_state.dart               ← 공통 빈 상태 위젯
    invite_join_dialog.dart        ← 초대 코드 참여 다이얼로그
    invite_bottom_sheet.dart       ← 초대 링크 공유 바텀시트
```

**디자인 토큰 & AppBar 위계**:
- 색상/간격/모서리/타이포는 `theme/` 토큰(`AppColors`·`AppSpacing`·`AppRadius`·`AppTextStyles`)을 단일 출처로 사용. 새 화면·수정 시 하드코딩 대신 토큰 참조(기존 화면은 손댈 때 점진 치환).
- **AppBar 표면 위계**: 루트 4탭(홈·커뮤니티·글로벌 지도·프로필) = **라이트 앱바**(`app_theme`의 기본값), 여행상세·풀스크린 등 몰입 화면 = **다크 앱바**(각 화면에서 개별 설정).

**화면 흐름**:
`LoginScreen` / `OnboardingScreen` → `MainScreen` (BottomNav 4탭: 홈 / 커뮤니티 / 글로벌 지도 / 프로필) → `TripDetailScreen` (탭: 타임라인 / 지도, EDITOR 이상은 업로드 탭 추가)
> 업로드는 하단탭이 아니라 여행상세 내부 탭임. `TripDetailScreen`은 `MainScreen` 위에 `Navigator.push`되어 표시(하단탭은 가려짐, 뒤로가기로 복귀).

**지도 탭 주요 기능**:
- GPS 좌표 있는 미디어 → 경로 폴리라인 + 그룹 마커 (카드 스택, 최대 3장)
- GPS 없는 미디어 → 촬영 시각 기준 가장 가까운 GPS 포인트에 근사 배치 (주황 표시)
- 마커 탭 → 하단 패널에서 그룹 내 미디어 가로 스크롤 + 풀스크린 진입
- EDITOR 이상: 롱프레스 수동 위치 지정 모드
- 지도 타일: CartoDB Voyager (API 키 불필요, 도로/지명 포함)

**API**: `ApiService` (`dio` 패키지) — base URL `http://10.0.2.2:8080` (Android 에뮬레이터 → 호스트)
