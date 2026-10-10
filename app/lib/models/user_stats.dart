class UserStats {
  final int tripCount;
  final int mediaCount;
  final int joinedGroupCount;

  const UserStats({
    required this.tripCount,
    required this.mediaCount,
    required this.joinedGroupCount,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      tripCount: json['tripCount'] as int,
      mediaCount: json['mediaCount'] as int,
      joinedGroupCount: json['joinedGroupCount'] as int,
    );
  }
}
