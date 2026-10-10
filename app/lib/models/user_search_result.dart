/// 사용자 검색 결과 항목 (직접 초대용).
class UserSearchResult {
  final int id;
  final String? nickname;
  final String? email;
  final String? profileImageUrl;

  const UserSearchResult({
    required this.id,
    this.nickname,
    this.email,
    this.profileImageUrl,
  });

  /// 표시용 이름 — 닉네임 우선, 없으면 이메일.
  String get displayName => (nickname != null && nickname!.isNotEmpty)
      ? nickname!
      : (email ?? '이름 없음');

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'] as int,
      nickname: json['nickname'] as String?,
      email: json['email'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
    );
  }
}
