import 'package:dio/dio.dart';

/// Nominatim (OpenStreetMap) 역지오코딩 서비스.
/// 좌표당 API 호출은 1번, 결과는 인메모리 캐시에 저장.
/// - [reverseGeocode]: 도시명만 (글로벌 지도용 — 서울특별시)
/// - [reverseGeocodeDetailed]: 시구동 (여행 내 지도용 — 서울특별시 양천구 목동)
class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://nominatim.openstreetmap.org',
      headers: {'User-Agent': 'TripMapTrace/1.0 (contact@tripmaptrace.app)'},
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  // 좌표 → address 객체 캐시 (소수점 3자리 반올림 키)
  final Map<String, Map<String, dynamic>> _addressCache = {};

  String _key(double lat, double lng) =>
      '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';

  Future<Map<String, dynamic>?> _fetchAddress(double lat, double lng) async {
    final key = _key(lat, lng);
    if (_addressCache.containsKey(key)) return _addressCache[key];

    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/reverse',
        queryParameters: {'lat': lat, 'lon': lng, 'format': 'json'},
      );
      final address = resp.data?['address'] as Map<String, dynamic>?;
      if (address != null) _addressCache[key] = address;
      return address;
    } catch (_) {
      return null;
    }
  }

  /// 도시명만 반환. 글로벌 지도 핀 시트용.
  /// 예: 서울특별시 / 부산광역시 / 제주시
  Future<String?> reverseGeocode(double lat, double lng) async {
    final address = await _fetchAddress(lat, lng);
    if (address == null) return null;

    final city = address['city'] as String? ??
        address['town'] as String? ??
        address['village'] as String? ??
        address['county'] as String?;
    return city;
  }

  /// 시구동까지 반환. 여행 내 지도 미디어 상세 시트용.
  /// 예: 서울특별시 양천구 목동 / 부산광역시 해운대구 우동
  Future<String?> reverseGeocodeDetailed(double lat, double lng) async {
    final address = await _fetchAddress(lat, lng);
    if (address == null) return null;

    final city = address['city'] as String? ??
        address['town'] as String? ??
        address['village'] as String? ??
        address['county'] as String?;
    final district = address['city_district'] as String?;
    final suburb = address['suburb'] as String? ??
        address['neighbourhood'] as String? ??
        address['quarter'] as String?;

    final parts = [?city, ?district, ?suburb];
    return parts.isEmpty ? null : parts.join(' ');
  }
}
