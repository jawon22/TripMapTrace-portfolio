class CommentItem {
  final int id;
  final int mediaId;
  final int userId;
  final String? nickname;
  final String content;
  final DateTime createdAt;

  const CommentItem({
    required this.id,
    required this.mediaId,
    required this.userId,
    required this.nickname,
    required this.content,
    required this.createdAt,
  });

  factory CommentItem.fromJson(Map<String, dynamic> json) {
    return CommentItem(
      id: json['id'] as int,
      mediaId: json['mediaId'] as int,
      userId: json['userId'] as int,
      nickname: json['nickname'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
