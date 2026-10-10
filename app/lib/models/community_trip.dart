class CommunityTripSummary {
  final int id;
  final String title;
  final String? startDate;
  final String? endDate;
  final String? coverThumbnailUrl;
  final int memberCount;
  final int mediaCount;
  int likeCount;
  int commentCount;
  bool isLiked;

  CommunityTripSummary({
    required this.id,
    required this.title,
    this.startDate,
    this.endDate,
    this.coverThumbnailUrl,
    required this.memberCount,
    required this.mediaCount,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
  });

  factory CommunityTripSummary.fromJson(Map<String, dynamic> json) {
    return CommunityTripSummary(
      id: json['id'] as int,
      title: json['title'] as String,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      coverThumbnailUrl: json['coverThumbnailUrl'] as String?,
      memberCount: json['memberCount'] as int? ?? 0,
      mediaCount: json['mediaCount'] as int? ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
    );
  }
}

class CommunityMediaItem {
  final int id;
  final String type;
  final String? thumbnailUrl;
  final String downloadUrl;
  final String? takenAt;
  final double? lat;
  final double? lng;

  const CommunityMediaItem({
    required this.id,
    required this.type,
    this.thumbnailUrl,
    required this.downloadUrl,
    this.takenAt,
    this.lat,
    this.lng,
  });

  factory CommunityMediaItem.fromJson(Map<String, dynamic> json) {
    return CommunityMediaItem(
      id: json['id'] as int,
      type: json['type'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      downloadUrl: json['downloadUrl'] as String,
      takenAt: json['takenAt'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }
}

class CommunityCommentResponse {
  final int id;
  final String nickname;
  final String content;
  final String createdAt;
  final bool isMine;

  const CommunityCommentResponse({
    required this.id,
    required this.nickname,
    required this.content,
    required this.createdAt,
    required this.isMine,
  });

  factory CommunityCommentResponse.fromJson(Map<String, dynamic> json) {
    return CommunityCommentResponse(
      id: json['id'] as int,
      nickname: json['nickname'] as String? ?? '닉네임 없음',
      content: json['content'] as String,
      createdAt: json['createdAt'] as String,
      isMine: json['isMine'] as bool? ?? false,
    );
  }
}

class CommunityTripDetail {
  final int id;
  final String title;
  final String? startDate;
  final String? endDate;
  final String? coverThumbnailUrl;
  final int memberCount;
  int likeCount;
  int commentCount;
  bool isLiked;
  final List<CommunityMediaItem> media;
  final List<CommunityCommentResponse> recentComments;

  CommunityTripDetail({
    required this.id,
    required this.title,
    this.startDate,
    this.endDate,
    this.coverThumbnailUrl,
    required this.memberCount,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
    required this.media,
    required this.recentComments,
  });

  factory CommunityTripDetail.fromJson(Map<String, dynamic> json) {
    return CommunityTripDetail(
      id: json['id'] as int,
      title: json['title'] as String,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      coverThumbnailUrl: json['coverThumbnailUrl'] as String?,
      memberCount: json['memberCount'] as int? ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      media: (json['media'] as List<dynamic>?)
              ?.map((e) => CommunityMediaItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recentComments: (json['recentComments'] as List<dynamic>?)
              ?.map((e) => CommunityCommentResponse.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class CommunityPageResponse {
  final List<CommunityTripSummary> content;
  final int page;
  final int size;
  final int totalElements;
  final bool last;

  const CommunityPageResponse({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.last,
  });

  factory CommunityPageResponse.fromJson(Map<String, dynamic> json) {
    return CommunityPageResponse(
      content: (json['content'] as List<dynamic>)
          .map((e) => CommunityTripSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? 20,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      last: json['last'] as bool? ?? true,
    );
  }
}
