class Trip {
  final int id;
  final String title;
  final DateTime? startDate;
  final DateTime? endDate;
  final int createdBy;
  final DateTime createdAt;
  final String myRole;
  final String? coverThumbnailUrl;
  final int memberCount;
  final int mediaCount;
  final bool isPublic;

  const Trip({
    required this.id,
    required this.title,
    this.startDate,
    this.endDate,
    required this.createdBy,
    required this.createdAt,
    required this.myRole,
    this.coverThumbnailUrl,
    this.memberCount = 0,
    this.mediaCount = 0,
    this.isPublic = false,
  });

  bool get isOwner => myRole == 'OWNER';
  bool get canEdit => myRole == 'OWNER' || myRole == 'EDITOR';

  factory Trip.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? s) => s == null ? null : DateTime.tryParse(s);

    return Trip(
      id: json['id'] as int,
      title: json['title'] as String,
      startDate: parseDate(json['startDate'] as String?),
      endDate: parseDate(json['endDate'] as String?),
      createdBy: json['createdBy'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      myRole: json['myRole'] as String,
      coverThumbnailUrl: json['coverThumbnailUrl'] as String?,
      memberCount: json['memberCount'] as int? ?? 0,
      mediaCount: json['mediaCount'] as int? ?? 0,
      isPublic: json['isPublic'] as bool? ?? false,
    );
  }
}
