import 'dart:io';
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import '../theme/app_radius.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../services/api_service.dart';
import '../services/geocoding_service.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/empty_state.dart';

// 개별 파일의 업로드 상태
enum _UploadStatus { pending, uploading, done, failed }

class _UploadItem {
  final File file;
  final String mime;
  final String type; // 'PHOTO' | 'VIDEO'
  final Uint8List? thumbBytes; // VIDEO 썸네일

  _UploadStatus status = _UploadStatus.pending;
  double progress = 0.0; // 0.0 ~ 1.0
  String? errorMsg;

  _UploadItem({
    required this.file,
    required this.mime,
    required this.type,
    this.thumbBytes,
  });

  String get fileName => file.path.split(Platform.pathSeparator).last;
}

class UploadTab extends StatefulWidget {
  final ApiService api;
  final int tripId;
  final VoidCallback? onUploadComplete;

  const UploadTab({super.key, required this.api, required this.tripId, this.onUploadComplete});

  @override
  State<UploadTab> createState() => _UploadTabState();
}

class _UploadTabState extends State<UploadTab> {
  final ImagePicker _picker = ImagePicker();

  List<_UploadItem> _items = [];
  bool _uploading = false;

  // ── 미디어 선택 ──────────────────────────────────

  Future<void> _pickImages() async {
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      showErrorSnackBar(context, '사진 접근 권한이 필요합니다.');
      return;
    }

    final List<XFile> picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;

    final newItems = picked.map((x) {
      final lower = x.name.toLowerCase();
      final mime = lower.endsWith('.png') ? 'image/png' : 'image/jpeg';
      return _UploadItem(file: File(x.path), mime: mime, type: 'PHOTO');
    }).toList();

    setState(() => _items = [..._items, ...newItems]);
  }

  Future<void> _pickVideo() async {
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      showErrorSnackBar(context, '미디어 접근 권한이 필요합니다.');
      return;
    }

    final XFile? x = await _picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;

    final lower = x.name.toLowerCase();
    final mime = lower.endsWith('.mov') ? 'video/quicktime' : 'video/mp4';

    Uint8List? thumbBytes;
    try {
      thumbBytes = await VideoThumbnail.thumbnailData(
        video: x.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 80,
      );
    } catch (_) {}

    setState(() {
      _items = [
        ..._items,
        _UploadItem(
          file: File(x.path),
          mime: mime,
          type: 'VIDEO',
          thumbBytes: thumbBytes,
        ),
      ];
    });
  }

  void _removeItem(int index) {
    if (_uploading) return;
    setState(() => _items.removeAt(index));
  }

  void _clearAll() {
    if (_uploading) return;
    setState(() => _items = []);
  }

  // ── 업로드 플로우 ────────────────────────────────

  Future<void> _uploadAll() async {
    if (_items.isEmpty) {
      showErrorSnackBar(context, '업로드할 파일을 선택하세요.');
      return;
    }
    // Android 10+에서 사진 GPS EXIF 읽기에 필요
    await Permission.accessMediaLocation.request();
    final pending =
        _items.where((i) => i.status == _UploadStatus.pending).toList();
    if (pending.isEmpty) {
      showErrorSnackBar(context, '업로드할 파일이 없습니다.');
      return;
    }

    setState(() => _uploading = true);

    for (final item in pending) {
      await _uploadSingle(item);
    }

    setState(() => _uploading = false);

    final failCount =
        _items.where((i) => i.status == _UploadStatus.failed).length;
    if (failCount == 0) {
      setState(() => _items = []);
      showSuccessSnackBar(context, '모든 파일 업로드 완료!');
      widget.onUploadComplete?.call();
    } else {
      showErrorSnackBar(context, '$failCount개 파일 업로드 실패');
    }
  }

  Future<void> _uploadSingle(_UploadItem item) async {
    _setStatus(item, _UploadStatus.uploading, progress: 0.1);

    try {
      DateTime takenAt = DateTime.now();
      double? lat;
      double? lng;

      String? addressText;
      if (item.type == 'PHOTO') {
        final exif = await _readExif(item.file);
        if (exif.takenAt != null) takenAt = exif.takenAt!;
        lat = exif.lat;
        lng = exif.lng;
        if (lat != null && lng != null) {
          addressText = await GeocodingService.instance
              .reverseGeocode(lat, lng)
              .catchError((_) => null);
        }
      }

      // 영상 썸네일 먼저 업로드
      String? thumbStorageKey;
      if (item.type == 'VIDEO' && item.thumbBytes != null) {
        _setStatus(item, _UploadStatus.uploading, progress: 0.2);
        final thumbPresign = await widget.api.presignUpload(
          tripId: widget.tripId,
          originalFileName:
              'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: 'image/jpeg',
          type: 'PHOTO',
        );
        await widget.api.putToS3(
            thumbPresign.uploadUrl, item.thumbBytes!, 'image/jpeg');
        thumbStorageKey = thumbPresign.storageKey;
      }

      _setStatus(item, _UploadStatus.uploading, progress: 0.4);
      final presign = await widget.api.presignUpload(
        tripId: widget.tripId,
        originalFileName: item.fileName,
        contentType: item.mime,
        type: item.type,
      );

      _setStatus(item, _UploadStatus.uploading, progress: 0.6);
      final bytes = await item.file.readAsBytes();
      await widget.api.putToS3(presign.uploadUrl, bytes, item.mime);

      _setStatus(item, _UploadStatus.uploading, progress: 0.9);
      await widget.api.completeUpload(
        tripId: widget.tripId,
        storageKey: presign.storageKey,
        takenAt: takenAt,
        lat: lat,
        lng: lng,
        type: item.type,
        thumbnailKey: thumbStorageKey,
        addressText: addressText,
      );

      _setStatus(item, _UploadStatus.done, progress: 1.0);
    } catch (e) {
      _setStatus(item, _UploadStatus.failed);
      item.errorMsg = e.toString();
    }
  }

  void _setStatus(_UploadItem item, _UploadStatus status,
      {double? progress}) {
    setState(() {
      item.status = status;
      if (progress != null) item.progress = progress;
    });
  }

  // ── EXIF ─────────────────────────────────────────

  Future<_ExifResult> _readExif(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final tags = await readExifFromBytes(bytes);

      DateTime? takenAt;
      double? lat;
      double? lng;

      final dt = tags['EXIF DateTimeOriginal'] ??
          tags['Image DateTime'] ??
          tags['EXIF DateTimeDigitized'];
      if (dt != null) takenAt = _parseExifDateTime(dt.printable);

      final gpsLat = tags['GPS GPSLatitude'];
      final gpsLatRef = tags['GPS GPSLatitudeRef'];
      final gpsLon = tags['GPS GPSLongitude'];
      final gpsLonRef = tags['GPS GPSLongitudeRef'];

      if (gpsLat != null &&
          gpsLatRef != null &&
          gpsLon != null &&
          gpsLonRef != null) {
        lat = _gpsToDecimal(gpsLat.printable, gpsLatRef.printable);
        lng = _gpsToDecimal(gpsLon.printable, gpsLonRef.printable);
      }

      return _ExifResult(takenAt: takenAt, lat: lat, lng: lng);
    } catch (_) {
      return const _ExifResult();
    }
  }

  DateTime? _parseExifDateTime(String raw) {
    try {
      final parts = raw.split(' ');
      if (parts.length != 2) return null;
      final date = parts[0].split(':');
      final time = parts[1].split(':');
      if (date.length != 3 || time.length != 3) return null;
      return DateTime(
        int.parse(date[0]), int.parse(date[1]), int.parse(date[2]),
        int.parse(time[0]), int.parse(time[1]), int.parse(time[2]),
      );
    } catch (_) {
      return null;
    }
  }

  double _gpsToDecimal(String printable, String ref) {
    final cleaned = printable.replaceAll('[', '').replaceAll(']', '');
    final parts = cleaned
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length < 3) return 0.0;

    double parseRatio(String s) {
      if (s.contains('/')) {
        final p = s.split('/');
        final num = double.tryParse(p[0]) ?? 0.0;
        final den = double.tryParse(p[1]) ?? 1.0;
        return den == 0 ? 0.0 : num / den;
      }
      return double.tryParse(s) ?? 0.0;
    }

    double decimal = parseRatio(parts[0]) +
        parseRatio(parts[1]) / 60.0 +
        parseRatio(parts[2]) / 3600.0;

    final r = ref.toUpperCase().trim();
    if (r == 'S' || r == 'W') decimal = -decimal;
    return decimal;
  }

  // ── UI ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildButtons(),
          const SizedBox(height: 12),
          if (_items.isNotEmpty) ...[
            _buildUploadButton(),
            const SizedBox(height: 12),
            Expanded(child: _buildFileGrid()),
          ] else
            Expanded(child: _buildEmptyState()),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _uploading ? null : _pickImages,
            icon: const Icon(Icons.photo_library),
            label: const Text('사진 선택'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _uploading ? null : _pickVideo,
            icon: const Icon(Icons.videocam),
            label: const Text('영상 선택'),
          ),
        ),
        if (_items.isNotEmpty) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: _uploading ? null : _clearAll,
            icon: const Icon(Icons.clear_all),
            tooltip: '전체 초기화',
          ),
        ],
      ],
    );
  }

  Widget _buildUploadButton() {
    final pendingCount =
        _items.where((i) => i.status == _UploadStatus.pending).length;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: (_uploading || pendingCount == 0) ? null : _uploadAll,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.cloud_upload),
        label: Text(_uploading
            ? '업로드 중...'
            : '일괄 업로드 ($pendingCount개)'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyState(
      icon: Icons.cloud_upload_outlined,
      title: '사진 또는 영상을 선택하세요',
      subtitle: '사진은 여러 장 동시 선택 가능합니다',
    );
  }

  Widget _buildFileGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _items.length,
      itemBuilder: (_, i) => _buildFileCell(_items[i], i),
    );
  }

  Widget _buildFileCell(_UploadItem item, int index) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 썸네일
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: _buildThumb(item),
        ),
        // 상태 오버레이
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: _buildStatusOverlay(item),
        ),
        // 삭제 버튼 (pending 상태에서만)
        if (item.status == _UploadStatus.pending)
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => _removeItem(index),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        // VIDEO 뱃지
        if (item.type == 'VIDEO')
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.videocam,
                  size: 12, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildThumb(_UploadItem item) {
    if (item.type == 'VIDEO' && item.thumbBytes != null) {
      return Image.memory(item.thumbBytes!, fit: BoxFit.cover);
    }
    if (item.type == 'PHOTO') {
      return Image.file(item.file, fit: BoxFit.cover);
    }
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.videocam, color: Colors.grey),
    );
  }

  Widget _buildStatusOverlay(_UploadItem item) {
    switch (item.status) {
      case _UploadStatus.uploading:
        return Container(
          color: Colors.black38,
          child: Center(
            child: CircularProgressIndicator(
              value: item.progress,
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
        );
      case _UploadStatus.done:
        return Container(
          color: Colors.black26,
          child: const Center(
            child: Icon(Icons.check_circle, color: Colors.white, size: 32),
          ),
        );
      case _UploadStatus.failed:
        return Container(
          color: Colors.red.withValues(alpha: 0.5),
          child: const Center(
            child: Icon(Icons.error_outline, color: Colors.white, size: 32),
          ),
        );
      case _UploadStatus.pending:
        return const SizedBox.shrink();
    }
  }
}

class _ExifResult {
  final DateTime? takenAt;
  final double? lat;
  final double? lng;
  const _ExifResult({this.takenAt, this.lat, this.lng});
}
