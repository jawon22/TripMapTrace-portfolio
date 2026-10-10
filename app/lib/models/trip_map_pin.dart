class TripMapPin {
  final int tripId;
  final String title;
  final String? thumbnailUrl;
  final double lat;
  final double lng;
  final int mediaCount;
  final String myRole;

  const TripMapPin({
    required this.tripId,
    required this.title,
    this.thumbnailUrl,
    required this.lat,
    required this.lng,
    required this.mediaCount,
    required this.myRole,
  });

  factory TripMapPin.fromJson(Map<String, dynamic> json) {
    return TripMapPin(
      tripId: json['tripId'] as int,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      mediaCount: json['mediaCount'] as int,
      myRole: json['myRole'] as String? ?? 'VIEWER',
    );
  }
}
