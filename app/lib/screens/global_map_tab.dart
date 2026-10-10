import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/trip.dart';
import '../models/trip_map_pin.dart';
import '../services/api_service.dart';
import '../services/geocoding_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../widgets/map_header_pill.dart';
import 'trip_detail_screen.dart';

Trip _tripFromPin(TripMapPin pin) => Trip(
      id: pin.tripId,
      title: pin.title,
      createdBy: 0,
      createdAt: DateTime(0),
      myRole: pin.myRole,
    );

class GlobalMapTab extends StatefulWidget {
  final bool isActive;
  final int tapCount;

  const GlobalMapTab({super.key, required this.isActive, required this.tapCount});

  @override
  State<GlobalMapTab> createState() => _GlobalMapTabState();
}

class _GlobalMapTabState extends State<GlobalMapTab> {
  final ApiService _api = ApiService();
  final MapController _mapController = MapController();
  final _geocoding = GeocodingService.instance;

  static const LatLng _defaultCenter = LatLng(37.5665, 126.9780);

  LatLng _center = _defaultCenter;
  List<TripMapPin> _pins = [];

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _loadData();
  }

  @override
  void didUpdateWidget(GlobalMapTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      // 탭이 비활성 → 활성으로 전환: 이전 위치 유지하며 새로고침
      _loadData();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(_center, 8.0);
      });
    } else if (widget.isActive && widget.tapCount != oldWidget.tapCount) {
      // 이미 활성 상태에서 같은 탭 재탭: 초기 위치로 리셋
      _loadData();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(_defaultCenter, 8.0);
      });
    }
  }

  Future<void> _loadData() async {
    final pins = await _api.fetchMapPins().catchError((_) => <TripMapPin>[]);

    if (!mounted) return;

    LatLng center = _defaultCenter;
    if (pins.isNotEmpty) {
      center = LatLng(pins.first.lat, pins.first.lng);
    } else {
      final deviceLoc = await _getDeviceLocation();
      if (deviceLoc != null) center = deviceLoc;
    }

    setState(() {
      _pins = pins;
      _center = center;
    });
  }

  Future<LatLng?> _getDeviceLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  void _showRegionList() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _RegionListSheet(
        pins: _pins,
        geocoding: _geocoding,
        onPinSelected: (pin) {
          Navigator.pop(context);
          _mapController.move(LatLng(pin.lat, pin.lng), 11);
        },
      ),
    );
  }

  void _showPinSheet(TripMapPin pin) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => _PinDetailSheet(
        pin: pin,
        geocoding: _geocoding,
        onViewDetail: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TripDetailScreen(trip: _tripFromPin(pin)),
            ),
          );
        },
      ),
    );
  }

  List<Marker> _buildMarkers() {
    return _pins.map((pin) {
      return Marker(
        point: LatLng(pin.lat, pin.lng),
        width: 64,
        height: 72,
        child: GestureDetector(
          onTap: () => _showPinSheet(pin),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: pin.thumbnailUrl != null
                      ? Image.network(pin.thumbnailUrl!, fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              _markerPlaceholder())
                      : _markerPlaceholder(),
                ),
              ),
              // 말풍선 꼬리
              CustomPaint(
                size: const Size(12, 8),
                painter: _BubbleTailPainter(),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _markerPlaceholder() {
    return Container(
      color: Colors.blueGrey.shade100,
      child: const Icon(Icons.place, color: Colors.blueGrey, size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            key: ValueKey(_center),
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 8.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.tripmaptrace',
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 80,
                  size: const Size(44, 44),
                  markers: _buildMarkers(),
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.amber.shade600,
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${markers.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          // 상단 pill 바
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: MapHeaderPill(
              title: '내 여행 지도',
              trailing: _pins.isNotEmpty
                  ? GestureDetector(
                      onTap: _showRegionList,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade600,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_pins.length}개 지역',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right,
                                size: 14, color: Colors.white),
                          ],
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          // 핀이 없을 때 안내 카드
          if (_pins.isEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.public,
                          size: 36, color: AppColors.accent),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '아직 여행 지도가 비어 있어요',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOnLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '여행이 쌓일수록\n나만의 세계 지도가 완성돼요',
                      style: TextStyle(fontSize: 13, color: AppColors.textSub, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Pin detail bottom sheet ───────────────────────────────────────────────────

class _PinDetailSheet extends StatefulWidget {
  final TripMapPin pin;
  final GeocodingService geocoding;
  final VoidCallback onViewDetail;

  const _PinDetailSheet({
    required this.pin,
    required this.geocoding,
    required this.onViewDetail,
  });

  @override
  State<_PinDetailSheet> createState() => _PinDetailSheetState();
}

class _PinDetailSheetState extends State<_PinDetailSheet> {
  String? _locationName;

  @override
  void initState() {
    super.initState();
    widget.geocoding
        .reverseGeocode(widget.pin.lat, widget.pin.lng)
        .then((name) {
      if (mounted && name != null) {
        setState(() => _locationName = name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pin = widget.pin;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildThumbnail(pin),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pin.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.photo_outlined,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${pin.mediaCount}개의 미디어',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          _locationName ??
                              '${pin.lat.toStringAsFixed(4)}, '
                                  '${pin.lng.toStringAsFixed(4)}',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.onViewDetail,
              child: const Text('자세히 보기'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(TripMapPin pin) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 72,
        height: 72,
        child: pin.thumbnailUrl != null
            ? Image.network(
                pin.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.map_outlined, color: Colors.grey),
    );
  }
}

// ── Region list bottom sheet ──────────────────────────────────────────────────

class _RegionListSheet extends StatefulWidget {
  final List<TripMapPin> pins;
  final GeocodingService geocoding;
  final void Function(TripMapPin) onPinSelected;

  const _RegionListSheet({
    required this.pins,
    required this.geocoding,
    required this.onPinSelected,
  });

  @override
  State<_RegionListSheet> createState() => _RegionListSheetState();
}

class _RegionListSheetState extends State<_RegionListSheet> {
  final Map<int, String?> _locationNames = {};

  @override
  void initState() {
    super.initState();
    for (final pin in widget.pins) {
      widget.geocoding.reverseGeocode(pin.lat, pin.lng).then((name) {
        if (mounted) setState(() => _locationNames[pin.tripId] = name);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Text('여행 지역',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Text('${widget.pins.length}개',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.pins.length,
            itemBuilder: (_, i) {
              final pin = widget.pins[i];
              final locationName = _locationNames[pin.tripId];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: pin.thumbnailUrl != null
                        ? Image.network(
                            pin.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                ),
                title: Text(pin.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  locationName ?? '위치 확인 중...',
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () => widget.onPinSelected(pin),
              );
            },
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.map_outlined, color: Colors.grey),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
