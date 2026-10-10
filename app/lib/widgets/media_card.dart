import 'package:flutter/material.dart';
import '../theme/app_radius.dart';
import '../models/media_item.dart';

class MediaCard extends StatelessWidget {
  final MediaItem item;

  const MediaCard({super.key, required this.item});

  String _formatUtcToLocal(DateTime? utc) {
    if (utc == null) return '-';
    final local = utc.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    // VIDEO는 thumbnailUrl 우선, 없으면 이미지 로드 안 함 (mp4를 Image로 로드 시 크래시)
    // PHOTO는 thumbnailUrl 우선, 없으면 downloadUrl
    final isVideo = item.type == 'VIDEO';
    final url = item.thumbnailUrl ?? (isVideo ? null : item.downloadUrl);

    Widget preview;
    if (url != null && url.isNotEmpty) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.network(url, fit: BoxFit.cover),
      );
    } else if (isVideo) {
      preview = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam, size: 40, color: Colors.black38),
          SizedBox(height: 4),
          Text('영상 (썸네일 생성 중...)',
              style: TextStyle(fontSize: 12, color: Colors.black45)),
        ],
      );
    } else {
      preview = const Text('미리보기 URL이 없습니다.');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '미디어 #${item.id} • ${item.type} • ${item.status}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text('촬영: ${_formatUtcToLocal(item.takenAt)}'),
            if (item.addressText != null) Text('장소: ${item.addressText}'),
            if (item.lat != null && item.lng != null)
              Text('좌표: ${item.lat}, ${item.lng}'),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: preview,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
