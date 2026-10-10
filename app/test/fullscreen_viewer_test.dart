import 'package:app/models/media_item.dart';
import 'package:app/widgets/fullscreen_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 테스트용 사진 MediaItem 생성 헬퍼.
MediaItem photo(int id) => MediaItem(
      id: id,
      type: 'PHOTO',
      takenAt: DateTime.utc(2026, 7, 5, 12, 0),
      lat: null,
      lng: null,
      addressText: null,
      storageKey: 'key$id',
      thumbnailKey: null,
      status: 'READY',
      downloadUrl: 'https://example.com/$id.jpg',
      thumbnailUrl: 'https://example.com/${id}_thumb.jpg',
      uploaderNickname: null,
      tripTitle: null,
      likeCount: 0,
      isLiked: false,
      commentCount: 0,
    );

void main() {
  testWidgets('canDownload=true 이면 다운로드 아이콘이 노출되고 인덱스가 표시된다',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FullscreenViewer(
        items: [photo(1), photo(2)],
        initialIndex: 0,
        canDownload: true,
      ),
    ));

    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('canDownload=false(기본값) 이면 다운로드 아이콘이 숨겨진다',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FullscreenViewer(
        items: [photo(1)],
        initialIndex: 0,
      ),
    ));

    expect(find.byIcon(Icons.download_outlined), findsNothing);
  });

  testWidgets('api/tripId 없이 열면 좋아요·댓글 오버레이가 렌더되지 않는다 (커뮤니티/프로필 경로)',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FullscreenViewer(
        items: [photo(1)],
        initialIndex: 0,
        showNickname: false,
      ),
    ));

    // api == null 이므로 오버레이(LikeButton) 미노출
    expect(find.byType(LikeButton), findsNothing);
    // 뷰어 자체는 정상 빌드
    expect(find.byType(FullscreenViewer), findsOneWidget);
  });
}
