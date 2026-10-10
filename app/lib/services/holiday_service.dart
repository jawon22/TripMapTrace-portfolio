import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'api_service.dart';

class HolidayService {
  static final HolidayService instance = HolidayService._();
  HolidayService._();

  static const _cacheFile = 'holidays_cache.json';
  static const _cacheDays = 180;

  Set<String> _holidays = {};
  bool _loaded = false;

  /// 캐시 또는 백엔드 API에서 공휴일 로드. 실패 시 빈 셋으로 조용히 처리.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      await _loadFromCacheOrApi();
    } catch (_) {}
    _loaded = true;
  }

  bool isHoliday(DateTime day) {
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return _holidays.contains(key);
  }

  Future<void> _loadFromCacheOrApi() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_cacheFile');

    if (await file.exists()) {
      try {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final fetchedAt = DateTime.parse(json['fetchedAt'] as String);
        if (DateTime.now().difference(fetchedAt).inDays < _cacheDays) {
          _holidays = Set<String>.from(json['holidays'] as List);
          return;
        }
      } catch (_) {
        // 캐시 손상 → API 재요청
      }
    }

    await _fetchAndCache(file);
  }

  Future<void> _fetchAndCache(File cache) async {
    final now = DateTime.now();
    final holidays = await ApiService().fetchHolidays();

    _holidays = Set<String>.from(holidays);

    try {
      await cache.writeAsString(jsonEncode({
        'fetchedAt': now.toIso8601String(),
        'holidays': holidays,
      }));
    } catch (_) {}
  }
}
