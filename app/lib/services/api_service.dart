import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/comment_item.dart';
import '../models/community_trip.dart';
import '../models/media_item.dart';
import '../models/received_invitation.dart';
import '../models/trip.dart';
import '../models/trip_map_pin.dart';
import '../models/trip_stats.dart';
import '../models/user_search_result.dart';
import '../models/user_stats.dart';
import '../screens/login_screen.dart';
import 'auth_service.dart';

class ApiService {
  static const String _base = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _base,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ));
    _dio.interceptors.add(_AuthInterceptor());
  }

  // ── Auth ──────────────────────────────────────────

  Future<({String token, int userId, String? nickname, String? profileImageUrl, bool onboardingDone})> login(String email, String password) async {
    final resp = await _dio.post('/api/v1/auth/login',
        data: {'email': email, 'password': password});
    return (
      token: resp.data['token'] as String,
      userId: resp.data['userId'] as int,
      nickname: resp.data['nickname'] as String?,
      profileImageUrl: resp.data['profileImageUrl'] as String?,
      onboardingDone: resp.data['onboardingDone'] as bool? ?? false,
    );
  }

  Future<({String token, int userId, String? nickname, String? profileImageUrl, bool onboardingDone})> register(
      String email, String password, String nickname,
      {bool pushAgreed = false, bool marketingAgreed = false}) async {
    final resp = await _dio.post('/api/v1/auth/register', data: {
      'email': email,
      'password': password,
      'nickname': nickname,
      'pushAgreed': pushAgreed,
      'marketingAgreed': marketingAgreed,
    });
    return (
      token: resp.data['token'] as String,
      userId: resp.data['userId'] as int,
      nickname: resp.data['nickname'] as String?,
      profileImageUrl: resp.data['profileImageUrl'] as String?,
      onboardingDone: resp.data['onboardingDone'] as bool? ?? false,
    );
  }

  Future<({String token, int userId, String? nickname, String? profileImageUrl, bool onboardingDone})> oauthLogin(
      String provider, String token) async {
    final resp = await _dio.post('/api/v1/auth/oauth/$provider',
        data: {'token': token});
    return (
      token: resp.data['token'] as String,
      userId: resp.data['userId'] as int,
      nickname: resp.data['nickname'] as String?,
      profileImageUrl: resp.data['profileImageUrl'] as String?,
      onboardingDone: resp.data['onboardingDone'] as bool? ?? false,
    );
  }

  Future<void> completeOnboarding() async {
    await _dio.patch('/api/v1/users/me/onboarding');
  }

  /// 비밀번호 재설정 이메일 발송 요청
  Future<void> requestPasswordReset(String email) async {
    await _dio.post('/api/v1/auth/password/reset-request', data: {'email': email});
  }

  /// 재설정 토큰 + 새 비밀번호로 비밀번호 교체
  Future<void> resetPassword(String token, String newPassword) async {
    await _dio.post('/api/v1/auth/password/reset',
        data: {'token': token, 'newPassword': newPassword});
  }

  /// 로그인 상태에서 비밀번호 변경 (이메일 유저 전용)
  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _dio.patch('/api/v1/users/me/password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword});
  }

  /// 본인이 OWNER인 여행 목록 조회 (계정 탈퇴 전 체크용)
  Future<List<Map<String, dynamic>>> fetchOwnerTrips() async {
    final resp = await _dio.get('/api/v1/users/me/owner-trips');
    return (resp.data as List).cast<Map<String, dynamic>>();
  }

  /// 계정 탈퇴 (모든 멤버십 제거 + 유저 레코드 삭제)
  Future<void> deleteAccount() async {
    await _dio.delete('/api/v1/users/me');
  }

  Future<UserStats> fetchUserStats() async {
    final resp = await _dio.get('/api/v1/users/me/stats');
    return UserStats.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<MediaItem>> fetchMyMedia() async {
    final resp = await _dio.get('/api/v1/users/me/media');
    return (resp.data as List)
        .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MediaItem> toggleLike(int tripId, int mediaId) async {
    final resp = await _dio.post('/api/v1/trips/$tripId/media/$mediaId/like');
    return MediaItem.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> fetchMe() async {
    final resp = await _dio.get('/api/v1/users/me');
    return resp.data as Map<String, dynamic>;
  }

  Future<({String uploadUrl, String storageKey})> presignAvatar({
    required String originalFileName,
    required String contentType,
  }) async {
    final resp = await _dio.post('/api/v1/users/me/avatar/presign', data: {
      'originalFileName': originalFileName,
      'contentType': contentType,
    });
    return (
      uploadUrl: resp.data['uploadUrl'] as String,
      storageKey: resp.data['storageKey'] as String,
    );
  }

  Future<Map<String, dynamic>> completeAvatar(String storageKey) async {
    final resp = await _dio.patch('/api/v1/users/me/avatar/complete',
        data: {'storageKey': storageKey});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateNickname(String nickname) async {
    final resp = await _dio.patch('/api/v1/users/me/nickname',
        data: {'nickname': nickname});
    return resp.data as Map<String, dynamic>;
  }

  Future<void> updateFcmToken(String fcmToken) async {
    await _dio.patch('/api/v1/users/me/fcm-token', data: {'fcmToken': fcmToken});
  }

  Future<Map<String, dynamic>> fetchNotificationSettings() async {
    final resp = await _dio.get('/api/v1/users/me/notification-settings');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateNotificationSettings({
    required bool notifyUpload,
    required bool notifyJoin,
    required bool notifyRoleChange,
  }) async {
    final resp = await _dio.patch('/api/v1/users/me/notification-settings', data: {
      'notifyUpload': notifyUpload,
      'notifyJoin': notifyJoin,
      'notifyRoleChange': notifyRoleChange,
    });
    return resp.data as Map<String, dynamic>;
  }

  // ── 알림 ──────────────────────────────────────────

  Future<List<dynamic>> fetchNotifications() async {
    final resp = await _dio.get('/api/v1/notifications');
    return resp.data as List<dynamic>;
  }

  Future<int> fetchUnreadCount() async {
    final resp = await _dio.get('/api/v1/notifications/unread-count');
    return (resp.data as num).toInt();
  }

  Future<void> markNotificationRead(int id) async {
    await _dio.patch('/api/v1/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _dio.patch('/api/v1/notifications/read-all');
  }

  Future<void> deleteNotification(int id) async {
    await _dio.delete('/api/v1/notifications/$id');
  }

  Future<List<String>> fetchHolidays() async {
    final resp = await _dio.get('/api/v1/holidays');
    return (resp.data as List).cast<String>();
  }

  Future<List<TripMapPin>> fetchMapPins() async {
    final resp = await _dio.get('/api/v1/trips/map-pins');
    return (resp.data as List)
        .map((e) => TripMapPin.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Trip ──────────────────────────────────────────

  Future<List<Trip>> fetchTrips() async {
    final resp = await _dio.get('/api/v1/trips');
    return (resp.data as List)
        .map((e) => Trip.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Trip> createTrip(String title,
      {DateTime? startDate, DateTime? endDate}) async {
    final resp = await _dio.post('/api/v1/trips', data: {
      'title': title,
      if (startDate != null) 'startDate': _fmtDate(startDate),
      if (endDate != null) 'endDate': _fmtDate(endDate),
    });
    return Trip.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Trip> updateTrip(int tripId, String title,
      {DateTime? startDate, DateTime? endDate}) async {
    final resp = await _dio.patch('/api/v1/trips/$tripId', data: {
      'title': title,
      'startDate': startDate != null ? _fmtDate(startDate) : null,
      'endDate': endDate != null ? _fmtDate(endDate) : null,
    });
    return Trip.fromJson(resp.data as Map<String, dynamic>);
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> deleteTrip(int tripId) async {
    await _dio.delete('/api/v1/trips/$tripId');
  }

  Future<TripStats> fetchTripStats(int tripId) async {
    final resp = await _dio.get('/api/v1/trips/$tripId/stats');
    return TripStats.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> setTripCover(int tripId, int mediaId) async {
    await _dio.patch('/api/v1/trips/$tripId/cover', data: {'mediaId': mediaId});
  }

  Future<Trip> setTripVisibility(int tripId, {required bool isPublic}) async {
    final resp = await _dio.patch('/api/v1/trips/$tripId/visibility',
        data: {'isPublic': isPublic});
    return Trip.fromJson(resp.data as Map<String, dynamic>);
  }

  // ── Invite ────────────────────────────────────────

  /// 유효 토큰 재사용, 만료/소진 시 신규 발급
  Future<Map<String, dynamic>> generateInvite(int tripId) async {
    final resp = await _dio.post('/api/v1/trips/$tripId/invites');
    return resp.data as Map<String, dynamic>;
  }

  Future<void> joinByToken(String token) async {
    await _dio.post('/api/v1/invites/$token/join');
  }

  /// 딥링크 탭 시 여행 정보 미리보기 (인증 불필요)
  Future<Map<String, dynamic>> fetchInviteInfo(String token) async {
    final resp = await _dio.get('/api/v1/invite/$token/info');
    return resp.data as Map<String, dynamic>;
  }

  /// 현재 초대 토큰 상태 조회
  Future<Map<String, dynamic>> fetchInviteStatus(int tripId) async {
    final resp = await _dio.get('/api/v1/trips/$tripId/invite/status');
    return resp.data as Map<String, dynamic>;
  }

  // ── Direct Invitation (요청→수락) ──────────────────

  /// 닉네임 부분일치 또는 이메일 정확일치로 사용자 검색
  Future<List<UserSearchResult>> searchUsers(String q) async {
    final resp = await _dio.get('/api/v1/users/search',
        queryParameters: {'q': q});
    return (resp.data as List)
        .map((e) => UserSearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 특정 사용자에게 초대 요청 발송 (OWNER만)
  Future<void> sendInvitation(int tripId, int inviteeUserId) async {
    await _dio.post('/api/v1/trips/$tripId/invitations',
        data: {'inviteeUserId': inviteeUserId});
  }

  /// 내가 받은 대기중 초대 목록
  Future<List<ReceivedInvitation>> fetchMyInvitations() async {
    final resp = await _dio.get('/api/v1/me/invitations');
    return (resp.data as List)
        .map((e) => ReceivedInvitation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 초대 수락 → 참여한 tripId 반환
  Future<int> acceptInvitation(int invitationId) async {
    final resp = await _dio.post('/api/v1/invitations/$invitationId/accept');
    return resp.data['tripId'] as int;
  }

  /// 초대 거절
  Future<void> declineInvitation(int invitationId) async {
    await _dio.post('/api/v1/invitations/$invitationId/decline');
  }

  // ── Members ───────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchMembers(int tripId) async {
    final resp = await _dio.get('/api/v1/trips/$tripId/members');
    return (resp.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> changeMemberRole(int tripId, int memberId, String role) async {
    await _dio.patch('/api/v1/trips/$tripId/members/$memberId/role',
        data: {'role': role});
  }

  Future<void> removeMember(int tripId, int memberId) async {
    await _dio.delete('/api/v1/trips/$tripId/members/$memberId');
  }

  Future<void> leaveTrip(int tripId) async {
    await _dio.delete('/api/v1/trips/$tripId/members/me');
  }

  // ── Media ─────────────────────────────────────────

  Future<List<MediaItem>> fetchMedia(int tripId) async {
    final resp = await _dio.get('/api/v1/trips/$tripId/media');
    return (resp.data as List)
        .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<({String uploadUrl, String storageKey})> presignUpload({
    required int tripId,
    required String originalFileName,
    required String contentType,
    required String type,
  }) async {
    final resp = await _dio.post(
      '/api/v1/trips/$tripId/media/presign',
      data: {
        'type': type,
        'originalFileName': originalFileName,
        'contentType': contentType,
      },
    );
    return (
      uploadUrl: resp.data['uploadUrl'] as String,
      storageKey: resp.data['storageKey'] as String,
    );
  }

  Future<MediaItem> completeUpload({
    required int tripId,
    required String storageKey,
    required DateTime takenAt,
    required double? lat,
    required double? lng,
    required String type,
    String? thumbnailKey,
    String? addressText,
  }) async {
    final resp = await _dio.post(
      '/api/v1/trips/$tripId/media/complete',
      data: {
        'type': type,
        'takenAt': takenAt.toUtc().toIso8601String(),
        'lat': lat,
        'lng': lng,
        'addressText': addressText,
        'storageKey': storageKey,
        'thumbnailKey': thumbnailKey,
      },
    );
    return MediaItem.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> deleteMedia(int tripId, int mediaId) async {
    await _dio.delete('/api/v1/trips/$tripId/media/$mediaId');
  }

  Future<void> updateMediaLocation(
      int tripId, int mediaId, double lat, double lng) async {
    await _dio.patch('/api/v1/trips/$tripId/media/$mediaId/location',
        data: {'lat': lat, 'lng': lng});
  }

  Future<String> getDownloadUrl(int tripId, int mediaId) async {
    final resp =
        await _dio.get('/api/v1/trips/$tripId/media/download-url/$mediaId');
    return resp.data['url'] as String;
  }

  // ── Comments ──────────────────────────────────────

  Future<List<CommentItem>> fetchComments(int tripId, int mediaId) async {
    final resp = await _dio.get('/api/v1/trips/$tripId/media/$mediaId/comments');
    return (resp.data as List)
        .map((e) => CommentItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CommentItem> addComment(int tripId, int mediaId, String content) async {
    final resp = await _dio.post(
      '/api/v1/trips/$tripId/media/$mediaId/comments',
      data: {'content': content},
    );
    return CommentItem.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<CommentItem> updateComment(
      int tripId, int mediaId, int commentId, String content) async {
    final resp = await _dio.patch(
      '/api/v1/trips/$tripId/media/$mediaId/comments/$commentId',
      data: {'content': content},
    );
    return CommentItem.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> deleteComment(int tripId, int mediaId, int commentId) async {
    await _dio.delete('/api/v1/trips/$tripId/media/$mediaId/comments/$commentId');
  }

  // ── Community ─────────────────────────────────────

  Future<CommunityPageResponse> fetchCommunityTrips({
    int page = 0,
    int size = 20,
    String sort = 'latest',
    String? keyword,
    bool onlyLiked = false,
  }) async {
    final resp = await _dio.get('/api/v1/community/trips', queryParameters: {
      'page': page,
      'size': size,
      'sort': sort,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      'onlyLiked': onlyLiked,
    });
    return CommunityPageResponse.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<CommunityTripDetail> fetchCommunityTripDetail(int tripId) async {
    final resp = await _dio.get('/api/v1/community/trips/$tripId');
    return CommunityTripDetail.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<bool> toggleCommunityTripLike(int tripId) async {
    final resp = await _dio.post('/api/v1/community/trips/$tripId/like');
    return (resp.data as Map<String, dynamic>)['isLiked'] as bool;
  }

  Future<List<CommunityCommentResponse>> fetchCommunityComments(int tripId) async {
    final resp = await _dio.get('/api/v1/community/trips/$tripId/comments');
    return (resp.data as List)
        .map((e) => CommunityCommentResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CommunityCommentResponse> addCommunityComment(int tripId, String content) async {
    final resp = await _dio.post(
      '/api/v1/community/trips/$tripId/comments',
      data: {'content': content},
    );
    return CommunityCommentResponse.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<CommunityCommentResponse> updateCommunityComment(
      int tripId, int commentId, String content) async {
    final resp = await _dio.patch(
      '/api/v1/community/trips/$tripId/comments/$commentId',
      data: {'content': content},
    );
    return CommunityCommentResponse.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> deleteCommunityComment(int tripId, int commentId) async {
    await _dio.delete('/api/v1/community/trips/$tripId/comments/$commentId');
  }

  Future<void> putToS3(
      String uploadUrl, List<int> bytes, String contentType) async {
    final s3Dio = Dio(BaseOptions(
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ));
    await s3Dio.put(
      uploadUrl,
      data: bytes,
      options: Options(headers: {'Content-Type': contentType}),
    );
  }
}

class _AuthInterceptor extends Interceptor {
  final _authService = AuthService();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _authService.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      final path = err.requestOptions.path;
      // 로그인/회원가입 요청의 401은 화면 이동 없이 그대로 에러 전달
      if (!path.startsWith('/api/v1/auth/')) {
        await _authService.logout();
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
    handler.next(err);
  }
}
