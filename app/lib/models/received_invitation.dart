/// 내가 받은 대기중(PENDING) 여행 초대.
class ReceivedInvitation {
  final int id;
  final int tripId;
  final String tripTitle;
  final String inviterNickname;
  final int memberCount;

  const ReceivedInvitation({
    required this.id,
    required this.tripId,
    required this.tripTitle,
    required this.inviterNickname,
    required this.memberCount,
  });

  factory ReceivedInvitation.fromJson(Map<String, dynamic> json) {
    return ReceivedInvitation(
      id: json['id'] as int,
      tripId: json['tripId'] as int,
      tripTitle: json['tripTitle'] as String? ?? '알 수 없는 여행',
      inviterNickname: json['inviterNickname'] as String? ?? '알 수 없음',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
    );
  }
}
