import 'dart:math' show sqrt, min;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';
import '../services/geocoding_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/empty_state.dart';
import '../widgets/fullscreen_viewer.dart';
import '../widgets/map_header_pill.dart';

class _PlacedMedia {
  final MediaItem item;
  final LatLng position;
  final bool isApproximate;
  const _PlacedMedia(this.item, this.position, {this.isApproximate = false});
}

class MapTab extends StatefulWidget {
  final ApiService api;
  final int tripId;
  final String myRole;
  const MapTab(
      {super.key,
      required this.api,
      required this.tripId,
      required this.myRole});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  List<MediaItem> _allMedia = [];
  List<MediaItem> _geoMedia = [];
  Map<LatLng, List<_PlacedMedia>> _groups = {};
  List<_PlacedMedia>? _expandedGroup;
  bool _loading = true;
  String? _error;
  MediaItem? _pickingMedia;
  bool _showPath = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await widget.api.fetchMedia(widget.tripId);

      final geoSorted = all
          .where((m) =>
              m.lat != null &&
              m.lng != null &&
              !(m.lat == 0.0 && m.lng == 0.0))
          .toList()
        ..sort((a, b) {
          final ta = a.takenAt ?? DateTime(0);
          final tb = b.takenAt ?? DateTime(0);
          return ta.compareTo(tb);
        });

      final placed = <_PlacedMedia>[];
      for (final m in geoSorted) {
        placed.add(_PlacedMedia(m, LatLng(m.lat!, m.lng!)));
      }

      if (geoSorted.isNotEmpty) {
        final noGeo = all.where((m) =>
            m.lat == null || m.lng == null || (m.lat == 0.0 && m.lng == 0.0));
        for (final m in noGeo) {
          final pos = _nearestGpsPoint(m.takenAt, geoSorted);
          placed.add(_PlacedMedia(m, pos, isApproximate: true));
        }
      }

      final groups = <LatLng, List<_PlacedMedia>>{};
      for (final p in placed) {
        groups.putIfAbsent(p.position, () => []).add(p);
      }
      for (final list in groups.values) {
        final gpsList = list.where((p) => !p.isApproximate).toList()
          ..sort((a, b) {
            final ta = a.item.takenAt ?? DateTime(0);
            final tb = b.item.takenAt ?? DateTime(0);
            return ta.compareTo(tb);
          });
        final primary = gpsList.first;
        final rest = list.where((p) => p != primary).toList()
          ..sort((a, b) {
            final ta = a.item.takenAt ?? DateTime(0);
            final tb = b.item.takenAt ?? DateTime(0);
            return ta.compareTo(tb);
          });
        list
          ..clear()
          ..add(primary)
          ..addAll(rest);
      }

      setState(() {
        _allMedia = all;
        _geoMedia = geoSorted;
        _groups = groups;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  LatLng _nearestGpsPoint(DateTime? takenAt, List<MediaItem> geoMedia) {
    if (takenAt == null) return LatLng(geoMedia.last.lat!, geoMedia.last.lng!);
    MediaItem nearest = geoMedia.first;
    var minDiff = takenAt.difference(nearest.takenAt ?? DateTime(0)).abs();
    for (final m in geoMedia.skip(1)) {
      final diff = takenAt.difference(m.takenAt ?? DateTime(0)).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = m;
      }
    }
    return LatLng(nearest.lat!, nearest.lng!);
  }

  void _showMediaDetail(_PlacedMedia placed) {
    final canEdit = widget.myRole != 'VIEWER';
    final groupItems = (_expandedGroup ?? [placed]).map((p) => p.item).toList();
    final itemIndex = groupItems.indexWhere((i) => i.id == placed.item.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => _MediaDetailSheet(
        media: placed.item,
        isApproximate: placed.isApproximate,
        onSetLocation: (canEdit && placed.isApproximate)
            ? () {
                Navigator.pop(context);
                setState(() => _pickingMedia = placed.item);
              }
            : null,
        onOpenFullscreen: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullscreenViewer(
                items: groupItems,
                initialIndex: itemIndex.clamp(0, groupItems.length - 1),
                api: widget.api,
                tripId: widget.tripId,
                canDownload: widget.myRole != 'VIEWER',
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onMapLongPress(TapPosition tapPos, LatLng latlng) async {
    if (_pickingMedia == null) return;
    final media = _pickingMedia!;
    setState(() => _pickingMedia = null);

    try {
      await widget.api.updateMediaLocation(
          widget.tripId, media.id, latlng.latitude, latlng.longitude);
      await _load();
      if (mounted) {
        showSuccessSnackBar(context, '위치가 저장되었습니다.');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, '위치 저장 실패: $e');
      }
    }
  }

  // ── Dashed polyline ───────────────────────────────

  List<Polyline> _buildDashedPolylines(List<LatLng> points) {
    if (points.length < 2) return [];
    const dashDeg = 0.0003;
    const gapDeg = 0.0002;
    final result = <Polyline>[];

    for (int i = 0; i < points.length - 1; i++) {
      final from = points[i];
      final to = points[i + 1];
      final dLat = to.latitude - from.latitude;
      final dLng = to.longitude - from.longitude;
      final segLen = sqrt(dLat * dLat + dLng * dLng);
      if (segLen == 0) continue;

      double covered = 0;
      bool draw = true;

      while (covered < segLen) {
        final pieceLen = draw ? dashDeg : gapDeg;
        final end = min(covered + pieceLen, segLen);

        if (draw) {
          final t0 = covered / segLen;
          final t1 = end / segLen;
          result.add(Polyline(
            points: [
              LatLng(
                  from.latitude + t0 * dLat, from.longitude + t0 * dLng),
              LatLng(
                  from.latitude + t1 * dLat, from.longitude + t1 * dLng),
            ],
            color: AppColors.accent,
            strokeWidth: 4,
          ));
        }

        covered = end;
        draw = !draw;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.black38),
            const SizedBox(height: 12),
            Text('불러오기 실패: $_error',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('재시도')),
          ],
        ),
      );
    }

    if (_geoMedia.isEmpty) {
      if (_allMedia.isEmpty) {
        return const EmptyState(
          icon: Icons.photo_library_outlined,
          title: '아직 사진이 없어요',
          subtitle: '사진을 업로드하면 지도에 표시됩니다',
        );
      }
      return const EmptyState(
        icon: Icons.location_off_outlined,
        title: 'GPS 정보가 없어요',
        subtitle: 'GPS 정보가 담긴 사진을 올리면\n지도에 경로가 기록됩니다',
      );
    }

    final points = _geoMedia.map((m) => LatLng(m.lat!, m.lng!)).toList();
    final center = points[points.length ~/ 2];

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13,
            onTap: (_, _) {
              if (_expandedGroup != null) {
                setState(() => _expandedGroup = null);
              }
            },
            onLongPress: _onMapLongPress,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.example.tripmaptrace',
            ),
            SimpleAttributionWidget(
              source: const Text('© OpenStreetMap & CARTO'),
            ),
            if (_showPath)
              PolylineLayer(polylines: _buildDashedPolylines(points)),
            MarkerLayer(
              markers: _groups.entries.map((entry) {
                final pos = entry.key;
                final group = entry.value;
                final isExpanded = _expandedGroup == group;
                const cardSize = 44.0;
                const stackOffset = 6.0;
                final displayCount = group.length.clamp(1, 3);
                final markerSize = cardSize + stackOffset * (displayCount - 1);
                return Marker(
                  point: pos,
                  width: markerSize,
                  height: markerSize,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _expandedGroup = isExpanded ? null : group;
                      });
                    },
                    child: _GroupMarker(group: group, isExpanded: isExpanded),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        // 지도 정체성 헤더
        const Positioned(
          top: 12,
          left: 12,
          child: MapHeaderPill(title: '이 여행의 동선'),
        ),
        // Path toggle button
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: () => setState(() => _showPath = !_showPath),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _showPath ? AppColors.accent : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 6)
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route,
                      size: 15,
                      color: _showPath ? Colors.white : AppColors.textSub),
                  const SizedBox(width: 4),
                  Text(
                    _showPath ? '경로 켜짐' : '경로 꺼짐',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _showPath ? Colors.white : AppColors.textSub,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expandedGroup != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {},
              child: _ExpandedGroupPanel(
                group: _expandedGroup!,
                onItemTap: _showMediaDetail,
                onClose: () => setState(() => _expandedGroup = null),
              ),
            ),
          ),
        if (_pickingMedia != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.orange.shade700,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('지도를 길게 눌러 위치를 선택하세요',
                          style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _pickingMedia = null),
                      child:
                          const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Marker widgets ────────────────────────────────────────────────────────────

class _GroupMarker extends StatelessWidget {
  final List<_PlacedMedia> group;
  final bool isExpanded;

  const _GroupMarker({required this.group, required this.isExpanded});

  static const double _cardSize = 44.0;
  static const double _stackOffset = 6.0;

  @override
  Widget build(BuildContext context) {
    final displayCount = group.length.clamp(1, 3);
    final totalSize = _cardSize + _stackOffset * (displayCount - 1);

    if (displayCount == 1) {
      return _buildCard(group.first, highlighted: isExpanded);
    }

    return SizedBox(
      width: totalSize,
      height: totalSize,
      child: Stack(
        children: [
          for (int i = displayCount - 1; i >= 0; i--)
            Positioned(
              left: i * _stackOffset,
              top: (displayCount - 1 - i) * _stackOffset,
              child: _buildCard(group[i], highlighted: i == 0 && isExpanded),
            ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: AppColors.destructive,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${group.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(_PlacedMedia p, {required bool highlighted}) {
    final isVideo = p.item.type == 'VIDEO';
    final imageUrl =
        p.item.thumbnailUrl ?? (isVideo ? null : p.item.downloadUrl);

    return Container(
      width: _cardSize,
      height: _cardSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: highlighted ? AppColors.accent : Colors.white,
          width: highlighted ? 2.5 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: imageUrl != null
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _iconContent(p),
              )
            : _iconContent(p),
      ),
    );
  }

  Widget _iconContent(_PlacedMedia p) {
    return Container(
      color: p.isApproximate ? Colors.orange.shade50 : Colors.grey.shade200,
      child: Icon(
        p.item.type == 'VIDEO' ? Icons.videocam : Icons.photo,
        size: _cardSize * 0.45,
        color: p.isApproximate ? Colors.orange : Colors.blueGrey,
      ),
    );
  }
}

// ── Expanded group bottom panel ───────────────────────────────────────────────

class _ExpandedGroupPanel extends StatelessWidget {
  final List<_PlacedMedia> group;
  final void Function(_PlacedMedia) onItemTap;
  final VoidCallback onClose;

  const _ExpandedGroupPanel({
    required this.group,
    required this.onItemTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final hasApproximate = group.any((p) => p.isApproximate);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -2))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${group.length}개 미디어',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              if (hasApproximate) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Text('위치 추정 포함',
                      style: TextStyle(fontSize: 11, color: Colors.orange)),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, size: 20, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: group.map((p) {
                final isVideo = p.item.type == 'VIDEO';
                return GestureDetector(
                  onTap: () => onItemTap(p),
                  child: Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: () {
                        final imageUrl = p.item.thumbnailUrl ??
                            (isVideo ? null : p.item.downloadUrl);
                        if (imageUrl != null) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                        color: Colors.grey.shade200,
                                        child: Icon(
                                            isVideo
                                                ? Icons.videocam
                                                : Icons.photo,
                                            color: Colors.black38),
                                      )),
                              if (isVideo)
                                const Align(
                                  alignment: Alignment.bottomRight,
                                  child: Padding(
                                    padding: EdgeInsets.all(3),
                                    child: Icon(Icons.videocam,
                                        size: 14,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                              color: Colors.black54,
                                              blurRadius: 4)
                                        ]),
                                  ),
                                ),
                            ],
                          );
                        }
                        return Container(
                          color: p.isApproximate
                              ? Colors.orange.shade50
                              : Colors.grey.shade200,
                          child: Icon(
                            isVideo ? Icons.videocam : Icons.photo,
                            color: p.isApproximate
                                ? Colors.orange
                                : Colors.grey,
                          ),
                        );
                      }(),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Media detail sheet ────────────────────────────────────────────────────────

class _MediaDetailSheet extends StatefulWidget {
  final MediaItem media;
  final bool isApproximate;
  final VoidCallback? onSetLocation;
  final VoidCallback? onOpenFullscreen;

  const _MediaDetailSheet({
    required this.media,
    this.isApproximate = false,
    this.onSetLocation,
    this.onOpenFullscreen,
  });

  @override
  State<_MediaDetailSheet> createState() => _MediaDetailSheetState();
}

class _MediaDetailSheetState extends State<_MediaDetailSheet> {
  String? _locationName;

  @override
  void initState() {
    super.initState();
    final m = widget.media;
    if (m.lat != null &&
        m.lng != null &&
        !(m.lat == 0.0 && m.lng == 0.0)) {
      GeocodingService.instance
          .reverseGeocodeDetailed(m.lat!, m.lng!)
          .then((name) {
        if (mounted && name != null) {
          setState(() => _locationName = name);
        }
      });
    }
  }

  Widget _buildPreview(MediaItem m) {
    final isVideo = m.type == 'VIDEO';
    final imageUrl = m.thumbnailUrl ?? (isVideo ? null : m.downloadUrl);

    if (imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Image.network(
          imageUrl,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator())),
          errorBuilder: (_, _, _) => const SizedBox(
            height: 200,
            child: Center(
                child:
                    Icon(Icons.broken_image, size: 48, color: Colors.black38)),
          ),
        ),
      );
    }
    if (isVideo) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam, size: 56, color: Colors.black38),
              SizedBox(height: 8),
              Text('영상 (썸네일 없음)',
                  style: TextStyle(color: Colors.black45, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final isApproximate = widget.isApproximate;
    final takenAt = media.takenAt?.toLocal();
    final dateStr = takenAt != null
        ? '${takenAt.year}-${takenAt.month.toString().padLeft(2, '0')}-'
            '${takenAt.day.toString().padLeft(2, '0')} '
            '${takenAt.hour.toString().padLeft(2, '0')}:'
            '${takenAt.minute.toString().padLeft(2, '0')}'
        : '촬영 시각 미상';

    final hasGps = media.lat != null &&
        media.lng != null &&
        !(media.lat == 0.0 && media.lng == 0.0);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.onOpenFullscreen,
            child: _buildPreview(media),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Colors.black54),
              const SizedBox(width: 4),
              Text(dateStr, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 4),
          if (hasGps)
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: Colors.black38),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _locationName != null
                        ? '$_locationName '
                          '(${media.lat!.toStringAsFixed(5)}, '
                          '${media.lng!.toStringAsFixed(5)})'
                        : '${media.lat!.toStringAsFixed(5)}, '
                          '${media.lng!.toStringAsFixed(5)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          else if (isApproximate)
            Row(
              children: [
                const Icon(Icons.location_searching,
                    size: 16, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  '위치 추정 (GPS 없음 — 촬영 시각 기준 근사 위치)',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.orange),
                ),
              ],
            ),
          if (widget.onSetLocation != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onSetLocation,
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('위치 직접 지정'),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
