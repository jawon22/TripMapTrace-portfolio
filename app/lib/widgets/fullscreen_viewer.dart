import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../models/comment_item.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import 'app_snackbar.dart';

/// presigned URL의 미디어를 임시 파일로 내려받아 기기 갤러리에 저장한다.
/// 타임라인 다중 다운로드와 뷰어 단건 다운로드가 공유한다.
Future<void> saveUrlToGallery({
  required String url,
  required bool isVideo,
  required int id,
}) async {
  final dio = Dio(BaseOptions(receiveTimeout: const Duration(minutes: 5)));
  final tempDir = await getTemporaryDirectory();
  final ext = isVideo ? 'mp4' : 'jpg';
  final tempPath = '${tempDir.path}/tripmaptrace_$id.$ext';
  await dio.download(url, tempPath);
  if (isVideo) {
    await Gal.putVideo(tempPath);
  } else {
    await Gal.putImage(tempPath);
  }
  File(tempPath).deleteSync(recursive: false);
}

// ── Fullscreen viewer ─────────────────────────────────────────────────────────

class FullscreenViewer extends StatefulWidget {
  final List<MediaItem> items;
  final int initialIndex;
  final ApiService? api;
  final int? tripId;
  final ValueChanged<MediaItem>? onItemChanged;
  final bool showNickname;
  final bool canDownload;

  const FullscreenViewer({
    super.key,
    required this.items,
    required this.initialIndex,
    this.api,
    this.tripId,
    this.onItemChanged,
    this.showNickname = true,
    this.canDownload = false,
  });

  @override
  State<FullscreenViewer> createState() => _FullscreenViewerState();
}

class _FullscreenViewerState extends State<FullscreenViewer> {
  late PageController _pageController;
  late int _currentIndex;
  late List<MediaItem> _items;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? utc) {
    if (utc == null) return '촬영 시각 미상';
    final local = utc.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  /// 현재 표시 중인 항목을 갤러리에 저장한다.
  Future<void> _downloadCurrent() async {
    if (_downloading) return;
    final item = _items[_currentIndex];
    String? url = item.downloadUrl;
    if (url == null && widget.api != null && widget.tripId != null) {
      try {
        url = await widget.api!.getDownloadUrl(widget.tripId!, item.id);
      } catch (_) {}
    }
    if (url == null) {
      if (mounted) showErrorSnackBar(context, '다운로드 URL을 가져올 수 없습니다.');
      return;
    }
    setState(() => _downloading = true);
    try {
      await saveUrlToGallery(url: url, isVideo: item.type == 'VIDEO', id: item.id);
      if (mounted) showSuccessSnackBar(context, '갤러리에 저장했습니다.');
    } catch (_) {
      if (mounted) showErrorSnackBar(context, '저장에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Widget _buildPage(MediaItem item) {
    final isVideo = item.type == 'VIDEO';

    if (isVideo) {
      final url = item.downloadUrl ?? item.thumbnailUrl;
      if (url != null) return _VideoPage(url: url);
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam, size: 80, color: Colors.white38),
            SizedBox(height: 12),
            Text('영상 (URL 없음)', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    final imageUrl = item.downloadUrl ?? item.thumbnailUrl;
    if (imageUrl != null) {
      return InteractiveViewer(
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white54)),
          errorBuilder: (_, _, _) => const Center(
            child: Icon(Icons.broken_image, size: 64, color: Colors.white38),
          ),
        ),
      );
    }
    return const Center(
      child: Icon(Icons.photo, size: 80, color: Colors.white38),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_currentIndex];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.tripTitle != null)
              Text(
                item.tripTitle!,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              _formatDate(item.takenAt),
              style: TextStyle(
                color: Colors.white,
                fontSize: item.tripTitle != null ? 12 : 14,
              ),
            ),
            Row(
              children: [
                Text(
                  '${_currentIndex + 1} / ${_items.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                if (widget.showNickname && item.uploaderNickname != null) ...[
                  const Text('  ·  ',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  Text(
                    item.uploaderNickname!,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
            if (item.addressText != null)
              Text(
                item.addressText!,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          if (widget.canDownload)
            _downloading
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.download_outlined),
                    tooltip: '갤러리에 저장',
                    onPressed: _downloadCurrent,
                  ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _items.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (_, index) => _buildPage(_items[index]),
          ),
          if (widget.api != null && widget.tripId != null)
            Positioned(
              right: 16,
              bottom: 32,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CommentButton(
                    key: ValueKey('fullscreen_comment_${item.id}'),
                    mediaId: item.id,
                    tripId: widget.tripId!,
                    commentCount: item.commentCount,
                    api: widget.api!,
                    onCountChanged: (newCount) {
                      final idx = _items.indexWhere((e) => e.id == item.id);
                      if (idx != -1) {
                        final updated = MediaItem(
                          id: _items[idx].id,
                          type: _items[idx].type,
                          takenAt: _items[idx].takenAt,
                          lat: _items[idx].lat,
                          lng: _items[idx].lng,
                          addressText: _items[idx].addressText,
                          storageKey: _items[idx].storageKey,
                          thumbnailKey: _items[idx].thumbnailKey,
                          status: _items[idx].status,
                          downloadUrl: _items[idx].downloadUrl,
                          thumbnailUrl: _items[idx].thumbnailUrl,
                          uploaderNickname: _items[idx].uploaderNickname,
                          tripTitle: _items[idx].tripTitle,
                          likeCount: _items[idx].likeCount,
                          isLiked: _items[idx].isLiked,
                          commentCount: newCount,
                        );
                        _items[idx] = updated;
                        widget.onItemChanged?.call(updated);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  LikeButton(
                    key: ValueKey('fullscreen_like_${item.id}'),
                    mediaId: item.id,
                    tripId: widget.tripId!,
                    likeCount: item.likeCount,
                    isLiked: item.isLiked,
                    api: widget.api!,
                    onChanged: (updated) {
                      final idx = _items.indexWhere((e) => e.id == updated.id);
                      if (idx != -1) {
                        _items[idx] = updated;
                        widget.onItemChanged?.call(updated);
                      }
                    },
                    compact: false,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Video page ─────────────────────────────────────────────────────────────────

class _VideoPage extends StatefulWidget {
  final String url;
  const _VideoPage({required this.url});

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  late VideoPlayerController _ctrl;
  bool _ready = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      }).catchError((_) {
        if (mounted) setState(() => _error = true);
      });
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.white38),
            SizedBox(height: 8),
            Text('영상을 불러올 수 없습니다.',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    if (!_ready) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white54));
    }
    return GestureDetector(
      onTap: () => _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _ctrl.value.aspectRatio,
              child: VideoPlayer(_ctrl),
            ),
          ),
          if (!_ctrl.value.isPlaying)
            const IgnorePointer(
              child: Icon(Icons.play_circle_outline,
                  size: 72, color: Colors.white70),
            ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: VideoProgressIndicator(
              _ctrl,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Comment button ─────────────────────────────────────────────────────────────

class _CommentButton extends StatefulWidget {
  final int mediaId;
  final int tripId;
  final int commentCount;
  final ApiService api;
  final ValueChanged<int> onCountChanged;

  const _CommentButton({
    super.key,
    required this.mediaId,
    required this.tripId,
    required this.commentCount,
    required this.api,
    required this.onCountChanged,
  });

  @override
  State<_CommentButton> createState() => _CommentButtonState();
}

class _CommentButtonState extends State<_CommentButton> {
  late int _commentCount;

  @override
  void initState() {
    super.initState();
    _commentCount = widget.commentCount;
  }

  @override
  void didUpdateWidget(_CommentButton old) {
    super.didUpdateWidget(old);
    _commentCount = widget.commentCount;
  }

  void _openSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentSheet(
        tripId: widget.tripId,
        mediaId: widget.mediaId,
        api: widget.api,
        onCountChanged: (count) {
          setState(() => _commentCount = count);
          widget.onCountChanged(count);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openSheet,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 32, color: Colors.white),
          if (_commentCount > 0)
            Text(
              '$_commentCount',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

// ── Comment sheet ──────────────────────────────────────────────────────────────

class _CommentSheet extends StatefulWidget {
  final int tripId;
  final int mediaId;
  final ApiService api;
  final ValueChanged<int> onCountChanged;

  const _CommentSheet({
    required this.tripId,
    required this.mediaId,
    required this.api,
    required this.onCountChanged,
  });

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<CommentItem> _comments = [];
  bool _loading = true;
  bool _sending = false;
  int? _myUserId;
  int? _editingCommentId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _myUserId = await AuthService().getUserId();
    try {
      final list = await widget.api.fetchComments(widget.tripId, widget.mediaId);
      if (mounted) setState(() { _comments = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      if (_editingCommentId != null) {
        // 수정 모드
        final updated = await widget.api
            .updateComment(widget.tripId, widget.mediaId, _editingCommentId!, text);
        final idx = _comments.indexWhere((c) => c.id == _editingCommentId);
        _controller.clear();
        if (idx >= 0 && mounted) {
          setState(() {
            _comments[idx] = updated;
            _editingCommentId = null;
          });
        }
      } else {
        // 신규 작성
        final added = await widget.api.addComment(widget.tripId, widget.mediaId, text);
        _controller.clear();
        if (mounted) {
          setState(() => _comments.add(added));
          widget.onCountChanged(_comments.length);
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startEdit(CommentItem comment) {
    setState(() {
      _editingCommentId = comment.id;
      _controller.text = comment.content;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingCommentId = null;
      _controller.clear();
    });
  }

  Future<void> _delete(CommentItem comment) async {
    try {
      await widget.api.deleteComment(widget.tripId, widget.mediaId, comment.id);
      if (mounted) {
        setState(() => _comments.removeWhere((c) => c.id == comment.id));
        widget.onCountChanged(_comments.length);
      }
    } catch (_) {}
  }

  String _formatTime(DateTime utc) {
    final local = utc.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}.${two(local.month)}.${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text('댓글 ${_comments.length}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _comments.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('첫 번째 댓글을 남겨보세요',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _comments.length,
                        itemBuilder: (_, i) {
                          final c = _comments[i];
                          final isMine = _myUserId != null && c.userId == _myUserId;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.accent.withAlpha(40),
                                  child: Text(
                                    (c.nickname ?? '?').substring(0, 1).toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(c.nickname ?? '닉네임 없음',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13)),
                                          const SizedBox(width: 6),
                                          Text(_formatTime(c.createdAt),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey)),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(c.content,
                                          style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                                if (isMine) ...[
                                  GestureDetector(
                                    onTap: () => _startEdit(c),
                                    child: const Padding(
                                      padding: EdgeInsets.only(left: 8, top: 2),
                                      child: Icon(Icons.edit_outlined,
                                          size: 18, color: Colors.grey),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _delete(c),
                                    child: const Padding(
                                      padding: EdgeInsets.only(left: 8, top: 2),
                                      child: Icon(Icons.delete_outline,
                                          size: 18, color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),
          const Divider(height: 1),
          if (_editingCommentId != null)
            Container(
              color: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text('댓글 수정 중',
                        style: TextStyle(fontSize: 12, color: AppColors.accent)),
                  ),
                  GestureDetector(
                    onTap: _cancelEdit,
                    child: const Icon(Icons.close, size: 16, color: AppColors.textSub),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: '댓글 입력...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            const BorderSide(color: AppColors.accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _sending
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        onPressed: _send,
                        icon: Icon(
                          _editingCommentId != null ? Icons.check : Icons.send,
                          color: AppColors.accent,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Like button ────────────────────────────────────────────────────────────────

class LikeButton extends StatefulWidget {
  final int mediaId;
  final int tripId;
  final int likeCount;
  final bool isLiked;
  final ApiService api;
  final ValueChanged<MediaItem> onChanged;
  final bool compact;

  const LikeButton({
    super.key,
    required this.mediaId,
    required this.tripId,
    required this.likeCount,
    required this.isLiked,
    required this.api,
    required this.onChanged,
    required this.compact,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late int _likeCount;
  late bool _isLiked;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.likeCount;
    _isLiked = widget.isLiked;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(LikeButton old) {
    super.didUpdateWidget(old);
    _likeCount = widget.likeCount;
    _isLiked = widget.isLiked;
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading) return;
    setState(() => _loading = true);
    _animCtrl.forward(from: 0);
    try {
      final updated = await widget.api.toggleLike(widget.tripId, widget.mediaId);
      if (mounted) {
        setState(() {
          _likeCount = updated.likeCount;
          _isLiked = updated.isLiked;
        });
        widget.onChanged(updated);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return GestureDetector(
        onTap: _toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scaleAnim,
                child: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 12,
                  color: _isLiked ? Colors.redAccent : Colors.white,
                ),
              ),
              if (_likeCount > 0) ...[
                const SizedBox(width: 3),
                Text(
                  '$_likeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scaleAnim,
            child: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              size: 32,
              color: _isLiked ? Colors.redAccent : Colors.white,
            ),
          ),
          if (_likeCount > 0)
            Text(
              '$_likeCount',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
