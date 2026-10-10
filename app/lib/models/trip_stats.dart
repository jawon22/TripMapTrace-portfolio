class TripStats {
  final double distanceKm;
  final int dayCount;
  final int locationCount;
  final int photoCount;
  final int videoCount;
  final List<MemberUploadStat> memberStats;

  const TripStats({
    required this.distanceKm,
    required this.dayCount,
    required this.locationCount,
    required this.photoCount,
    required this.videoCount,
    required this.memberStats,
  });

  factory TripStats.fromJson(Map<String, dynamic> json) {
    return TripStats(
      distanceKm: (json['distanceKm'] as num).toDouble(),
      dayCount: json['dayCount'] as int,
      locationCount: json['locationCount'] as int,
      photoCount: json['photoCount'] as int,
      videoCount: json['videoCount'] as int,
      memberStats: (json['memberStats'] as List)
          .map((e) => MemberUploadStat.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MemberUploadStat {
  final int userId;
  final String nickname;
  final int count;

  const MemberUploadStat({
    required this.userId,
    required this.nickname,
    required this.count,
  });

  factory MemberUploadStat.fromJson(Map<String, dynamic> json) {
    return MemberUploadStat(
      userId: json['userId'] as int,
      nickname: json['nickname'] as String,
      count: json['count'] as int,
    );
  }
}
