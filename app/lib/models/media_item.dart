class MediaItem {
  final int id;
  final String type;
  final DateTime? takenAt;
  final double? lat;
  final double? lng;
  final String? addressText;
  final String storageKey;
  final String? thumbnailKey;
  final String status;
  final String? downloadUrl;
  final String? thumbnailUrl;
  final String? uploaderNickname;
  final String? tripTitle;
  final int likeCount;
  final bool isLiked;
  final int commentCount;

  const MediaItem({
    required this.id,
    required this.type,
    required this.takenAt,
    required this.lat,
    required this.lng,
    required this.addressText,
    required this.storageKey,
    required this.thumbnailKey,
    required this.status,
    required this.downloadUrl,
    required this.thumbnailUrl,
    required this.uploaderNickname,
    required this.tripTitle,
    required this.likeCount,
    required this.isLiked,
    required this.commentCount,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseUtc(String? s) => s == null ? null : DateTime.tryParse(s);

    return MediaItem(
      id: json['id'] as int,
      type: json['type'] as String,
      takenAt: parseUtc(json['takenAt'] as String?),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      addressText: json['addressText'] as String?,
      storageKey: json['storageKey'] as String,
      thumbnailKey: json['thumbnailKey'] as String?,
      status: json['status'] as String,
      downloadUrl: json['downloadUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      uploaderNickname: json['uploaderNickname'] as String?,
      tripTitle: json['tripTitle'] as String?,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
    );
  }
}
