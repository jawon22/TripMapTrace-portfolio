import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/community_trip.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/empty_state.dart';
import '../widgets/fullscreen_viewer.dart';
import '../widgets/map_header_pill.dart';
import 'login_screen.dart';

class CommunityTab extends StatefulWidget {
  final int unreadCount;
  final VoidCallback onBellTap;
  final bool isGuest;

  const CommunityTab({
    super.key,
    this.unreadCount = 0,
    this.onBellTap = _noop,
    this.isGuest = false,
  });

  static void _noop() {}

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab> {
  final _api = ApiService();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  final List<CommunityTripSummary> _trips = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 0;
  String _sort = 'latest';
  bool _onlyLiked = false;
  String _keyword = '';

  static const _size = 20;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _trips.clear();
      _page = 0;
      _hasMore = true;
    });
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final result = await _api.fetchCommunityTrips(
        page: _page,
        size: _size,
        sort: _sort,
        keyword: _keyword.isEmpty ? null : _keyword,
        onlyLiked: _onlyLiked,
      );
      if (mounted) {
        setState(() {
          _trips.addAll(result.content);
          _page++;
          _hasMore = !result.last;
        });
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '피드 로드 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSortChanged(String sort) {
    if (_sort == sort) return;
    _sort = sort;
    _reset();
  }

  void _onLikedFilterChanged(bool v) {
    _onlyLiked = v;
    _reset();
  }

  void _onSearch(String v) {
    _keyword = v.trim();
    _reset();
  }

  bool _checkGuest() {
    if (!widget.isGuest) return false;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('로그인이 필요한 기능입니다.'),
        content: const Text('로그인 후 이용하실 수 있습니다.\n로그인 화면으로 이동하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            child: const Text('로그인하기', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return true;
  }

  Future<void> _toggleLike(CommunityTripSummary trip) async {
    if (_checkGuest()) return;
    try {
      final isLiked = await _api.toggleCommunityTripLike(trip.id);
      if (mounted) {
        setState(() {
          final delta = isLiked ? 1 : -1;
          trip.isLiked = isLiked;
          trip.likeCount = (trip.likeCount + delta).clamp(0, 999999);
        });
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '좋아요 실패: $e');
    }
  }

  void _openDetail(CommunityTripSummary summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommunityDetailSheet(
        api: _api,
        summary: summary,
        isGuest: widget.isGuest,
        onLikeToggled: (isLiked) {
          if (mounted) {
            setState(() {
              summary.isLiked = isLiked;
              summary.likeCount = (summary.likeCount + (isLiked ? 1 : -1)).clamp(0, 999999);
            });
          }
        },
        onCommentCountChanged: (delta) {
          if (mounted) {
            setState(() {
              summary.commentCount = (summary.commentCount + delta).clamp(0, 999999);
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('커뮤니티', style: TextStyle(color: AppColors.textOnDark, fontWeight: FontWeight.bold)),
        actions: [
          if (!widget.isGuest)
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppColors.textOnDark),
                onPressed: widget.onBellTap,
              ),
              if (widget.unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(
                      widget.unreadCount > 99 ? '99+' : '${widget.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(controller: _searchController, onSearch: _onSearch),
          _FilterBar(
            sort: _sort,
            onlyLiked: _onlyLiked,
            onSortChanged: _onSortChanged,
            onLikedFilterChanged: _onLikedFilterChanged,
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_trips.isEmpty && !_loading) {
      return RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async => _reset(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            EmptyState(
              icon: Icons.explore_outlined,
              title: '공개된 여행이 없습니다.',
              subtitle: '내 여행을 공개하거나 다른 여행이 공개되면 여기에 표시됩니다.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async => _reset(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _trips.length + (_loading ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == _trips.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
            );
          }
          return _TripFeedCard(
            trip: _trips[i],
            onTap: () => _openDetail(_trips[i]),
            onLike: () => _toggleLike(_trips[i]),
          );
        },
      ),
    );
  }
}

// ── 검색 바 ────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearch;

  const _SearchBar({required this.controller, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: '여행명 검색',
          prefixIcon: const Icon(Icons.search, color: AppColors.textSub),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textSub),
                  onPressed: () {
                    controller.clear();
                    onSearch('');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        onSubmitted: onSearch,
        textInputAction: TextInputAction.search,
      ),
    );
  }
}

// ── 필터/정렬 바 ──────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String sort;
  final bool onlyLiked;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<bool> onLikedFilterChanged;

  const _FilterBar({
    required this.sort,
    required this.onlyLiked,
    required this.onSortChanged,
    required this.onLikedFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Chip('최신순', sort == 'latest', () => onSortChanged('latest')),
            const SizedBox(width: 8),
            _Chip('인기순', sort == 'popular', () => onSortChanged('popular')),
            const SizedBox(width: 8),
            _Chip('댓글순', sort == 'comments', () => onSortChanged('comments')),
            const SizedBox(width: 8),
            _Chip('내가 찜한', onlyLiked, () => onLikedFilterChanged(!onlyLiked), icon: Icons.favorite),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _Chip(this.label, this.selected, this.onTap, {this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.accent : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? Colors.white : AppColors.textSub),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Colors.white : AppColors.textOnLight,
                )),
          ],
        ),
      ),
    );
  }
}

// ── 피드 카드 ─────────────────────────────────────────────────────────────────

class _TripFeedCard extends StatelessWidget {
  final CommunityTripSummary trip;
  final VoidCallback onTap;
  final VoidCallback onLike;

  const _TripFeedCard({required this.trip, required this.onTap, required this.onLike});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 커버 이미지
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: trip.coverThumbnailUrl != null
                    ? Image.network(trip.coverThumbnailUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textOnLight),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(_formatPeriod(), style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _stat(Icons.people_outline, '${trip.memberCount}명'),
                      const SizedBox(width: 12),
                      _stat(Icons.photo_library_outlined, '${trip.mediaCount}장'),
                      const Spacer(),
                      GestureDetector(
                        onTap: onLike,
                        child: Row(
                          children: [
                            Icon(trip.isLiked ? Icons.favorite : Icons.favorite_outline,
                                size: 18, color: trip.isLiked ? Colors.red : AppColors.textSub),
                            const SizedBox(width: 4),
                            Text('${trip.likeCount}', style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _stat(Icons.chat_bubble_outline, '${trip.commentCount}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPeriod() {
    if (trip.startDate == null) return '';
    final start = trip.startDate!.replaceAll('-', '.');
    if (trip.endDate == null || trip.endDate == trip.startDate) return start;
    return '$start ~ ${trip.endDate!.replaceAll('-', '.')}';
  }

  Widget _placeholder() => Container(
    color: Colors.grey.shade200,
    child: const Center(child: Icon(Icons.photo_outlined, size: 48, color: AppColors.textSub)),
  );

  Widget _stat(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSub),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
      ],
    );
  }
}

// ── 상세 바텀시트 ──────────────────────────────────────────────────────────────

class _CommunityDetailSheet extends StatefulWidget {
  final ApiService api;
  final CommunityTripSummary summary;
  final bool isGuest;
  final ValueChanged<bool> onLikeToggled;
  final ValueChanged<int> onCommentCountChanged;

  const _CommunityDetailSheet({
    required this.api,
    required this.summary,
    this.isGuest = false,
    required this.onLikeToggled,
    required this.onCommentCountChanged,
  });

  @override
  State<_CommunityDetailSheet> createState() => _CommunityDetailSheetState();
}

class _CommunityDetailSheetState extends State<_CommunityDetailSheet> {
  CommunityTripDetail? _detail;
  bool _loading = true;
  bool _liking = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await widget.api.fetchCommunityTripDetail(widget.summary.id);
      if (mounted) setState(() { _detail = detail; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorSnackBar(context, '상세 로드 실패: $e');
      }
    }
  }

  void _openCommentSheet(int tripId) {
    if (_checkGuest()) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentSheet(
        api: widget.api,
        tripId: tripId,
        onCountChanged: (delta) {
          if (mounted && _detail != null) {
            setState(() {
              _detail!.commentCount = (_detail!.commentCount + delta).clamp(0, 999999);
            });
            widget.onCommentCountChanged(delta);
          }
        },
      ),
    );
  }

  bool _checkGuest() {
    if (!widget.isGuest) return false;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('로그인이 필요한 기능입니다.'),
        content: const Text('로그인 후 이용하실 수 있습니다.\n로그인 화면으로 이동하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            child: const Text('로그인하기', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return true;
  }

  Future<void> _toggleLike() async {
    if (_checkGuest()) return;
    if (_liking || _detail == null) return;
    setState(() => _liking = true);
    try {
      final isLiked = await widget.api.toggleCommunityTripLike(widget.summary.id);
      if (mounted) {
        setState(() {
          final delta = isLiked ? 1 : -1;
          _detail!.isLiked = isLiked;
          _detail!.likeCount = (_detail!.likeCount + delta).clamp(0, 999999);
        });
        widget.onLikeToggled(isLiked);
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '좋아요 실패: $e');
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              // 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.summary.title,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textOnLight),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (widget.summary.startDate != null)
                            Text(_formatPeriod(), style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 16),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
              else if (_detail == null)
                const Expanded(child: Center(child: Text('불러오기 실패')))
              else
                Expanded(child: _buildContent(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    final detail = _detail!;
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        // PageView: 갤러리 / 지도
        SizedBox(
          height: 300,
          child: PageView(
            children: [
              _GalleryPage(media: detail.media),
              _MapPage(media: detail.media),
            ],
          ),
        ),
        // 페이지 힌트
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('← 갤러리 · 경로 지도 →', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ),
        ),
        const Divider(height: 1),
        // 좋아요 / 댓글 수
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: _toggleLike,
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        detail.isLiked ? Icons.favorite : Icons.favorite_outline,
                        key: ValueKey(detail.isLiked),
                        size: 24,
                        color: detail.isLiked ? Colors.red : AppColors.textSub,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('${detail.likeCount}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textOnLight)),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () => _openCommentSheet(detail.id),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 22, color: AppColors.textSub),
                    const SizedBox(width: 6),
                    Text('${detail.commentCount}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textOnLight)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 최근 댓글 미리보기
        if (detail.recentComments.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: detail.recentComments.map((c) => _CommentRow(comment: c)).toList(),
            ),
          ),
          if (detail.commentCount > 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: GestureDetector(
                onTap: () => _openCommentSheet(detail.id),
                child: Text('댓글 ${detail.commentCount}개 모두 보기 →',
                    style: const TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w600)),
              ),
            ),
        ] else
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('아직 댓글이 없습니다.', style: TextStyle(color: AppColors.textSub, fontSize: 13)),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _formatPeriod() {
    final s = widget.summary;
    if (s.startDate == null) return '';
    final start = s.startDate!.replaceAll('-', '.');
    if (s.endDate == null || s.endDate == s.startDate) return start;
    return '$start ~ ${s.endDate!.replaceAll('-', '.')}';
  }
}

class _CommentRow extends StatelessWidget {
  final CommunityCommentResponse comment;

  const _CommentRow({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(comment.nickname,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textOnLight)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(comment.content,
                style: const TextStyle(fontSize: 13, color: AppColors.textOnLight), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ── 갤러리 페이지 ─────────────────────────────────────────────────────────────

class _GalleryPage extends StatelessWidget {
  final List<CommunityMediaItem> media;

  const _GalleryPage({required this.media});

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return const Center(child: EmptyState(icon: Icons.photo_library_outlined, title: '사진이 없습니다.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2,
      ),
      itemCount: media.length,
      itemBuilder: (ctx, i) {
        final item = media[i];
        final url = item.thumbnailUrl ?? item.downloadUrl;
        return GestureDetector(
          onTap: () => _openFullscreen(context, i),
          child: Image.network(url, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image_outlined, color: AppColors.textSub))),
        );
      },
    );
  }

  void _openFullscreen(BuildContext context, int index) {
    // 커뮤니티 미디어를 공용 FullscreenViewer가 받는 MediaItem으로 변환한다.
    // (영상은 뷰어의 _VideoPage 경로로 재생 — 기존 Image.network 깨짐 버그 해결)
    final items = media
        .map((m) => MediaItem(
              id: m.id,
              type: m.type,
              takenAt: m.takenAt != null ? DateTime.tryParse(m.takenAt!) : null,
              lat: m.lat,
              lng: m.lng,
              addressText: null,
              storageKey: '',
              thumbnailKey: null,
              status: 'READY',
              downloadUrl: m.downloadUrl,
              thumbnailUrl: m.thumbnailUrl,
              uploaderNickname: null,
              tripTitle: null,
              likeCount: 0,
              isLiked: false,
              commentCount: 0,
            ))
        .toList();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => FullscreenViewer(
        items: items,
        initialIndex: index,
        showNickname: false,
      ),
    ));
  }
}


// ── 경로 지도 페이지 ──────────────────────────────────────────────────────────

class _MapPage extends StatefulWidget {
  final List<CommunityMediaItem> media;

  const _MapPage({required this.media});

  @override
  State<_MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<_MapPage> {
  final _mapController = MapController();
  late final List<CommunityMediaItem> _gpsMedia;
  late final Map<String, int> _dayMap;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _gpsMedia = widget.media.where((m) => m.lat != null && m.lng != null).toList();
    _dayMap = _buildDayMap();
    // 초기 화면 맞춤은 MapOptions.initialCameraFit이 담당한다.
    // (PageView 밖에서 미리 build되는 시점에 addPostFrameCallback으로 fitCamera를
    //  호출하면 컨트롤러 바인딩 전이라 무시돼 지도가 축소된 채로 보이던 버그를 해결.)
  }

  Map<String, int> _buildDayMap() {
    final dates = _gpsMedia
        .where((m) => m.takenAt != null)
        .map((m) => m.takenAt!.substring(0, 10))
        .toSet()
        .toList()
      ..sort();
    return {for (var i = 0; i < dates.length; i++) dates[i]: i + 1};
  }

  void _fitAllPoints() {
    if (_gpsMedia.isEmpty) return;
    final points = _gpsMedia.map((m) => LatLng(m.lat!, m.lng!)).toList();
    if (points.length == 1) {
      _mapController.move(points.first, 13);
      return;
    }
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
    );
  }

  void _goTo(int index) {
    if (index < 0 || index >= _gpsMedia.length) return;
    setState(() => _currentIndex = index);
    final item = _gpsMedia[index];
    _mapController.move(LatLng(item.lat!, item.lng!), 14);
  }

  String _dayLabel(CommunityMediaItem item) {
    if (item.takenAt == null) return '';
    final day = _dayMap[item.takenAt!.substring(0, 10)];
    return day != null ? '$day일차' : '';
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  /// 비선택 포인트 마커: 첫 지점은 출발(초록), 마지막은 도착(빨강),
  /// 그 사이는 순번(2,3,4…)이 적힌 회색 마커.
  Marker _baseMarker(int i) {
    final m = _gpsMedia[i];
    final point = LatLng(m.lat!, m.lng!);
    final isStart = i == 0;
    final isEnd = i == _gpsMedia.length - 1;

    if (isStart || isEnd) {
      return Marker(
        point: point,
        width: 30,
        height: 30,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isStart ? AppColors.success : AppColors.destructive,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Icon(
            isStart ? Icons.play_arrow_rounded : Icons.flag_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
      );
    }

    // 중간 지점: 순번 마커
    return Marker(
      point: point,
      width: 24,
      height: 24,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade500,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          '${i + 1}',
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// 현재 선택 포인트: 순번이 적힌 amber 강조 마커 (항상 맨 위).
  Marker _selectedMarker(int i) {
    final m = _gpsMedia[i];
    return Marker(
      point: LatLng(m.lat!, m.lng!),
      width: 32,
      height: 32,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accent,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Text(
          '${i + 1}',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_gpsMedia.isEmpty) {
      return const Center(
        child: EmptyState(icon: Icons.location_off_outlined, title: 'GPS 정보가 없습니다.'),
      );
    }

    final allPoints = _gpsMedia.map((m) => LatLng(m.lat!, m.lng!)).toList();
    final current = _gpsMedia[_currentIndex];
    final center = LatLng(
      allPoints.map((p) => p.latitude).reduce((a, b) => a + b) / allPoints.length,
      allPoints.map((p) => p.longitude).reduce((a, b) => a + b) / allPoints.length,
    );

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: _gpsMedia.length == 1 ? 13 : 5,
              // 첫 렌더에서 경로 전체가 화면에 맞춰 뜨도록 카메라를 고정한다.
              // (포인트 1개면 bounds가 0이 되므로 initialCenter+zoom fallback)
              initialCameraFit: _gpsMedia.length == 1
                  ? null
                  : CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(allPoints),
                      padding: const EdgeInsets.all(48),
                    ),
              // 지도 제스처 비활성화 → PageView 좌우 스와이프 복원
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              PolylineLayer(polylines: [
                Polyline(
                  points: allPoints,
                  strokeWidth: 3,
                  color: AppColors.accent.withValues(alpha: 0.7),
                ),
              ]),
              MarkerLayer(
                markers: [
                  // 비선택 포인트: 출발(초록)·도착(빨강) 또는 순번 마커
                  for (var i = 0; i < _gpsMedia.length; i++)
                    if (i != _currentIndex) _baseMarker(i),
                  // 현재 선택 포인트는 항상 맨 위에 amber 강조로 그린다.
                  _selectedMarker(_currentIndex),
                ],
              ),
            ],
              ),
              const Positioned(
                top: 12,
                left: 12,
                child: MapHeaderPill(title: '여행 경로'),
              ),
            ],
          ),
        ),
        // 네비게이션 패널
        _RouteNavPanel(
          item: current,
          index: _currentIndex,
          total: _gpsMedia.length,
          dayLabel: _dayLabel(current),
          timeLabel: _formatTime(current.takenAt ?? ''),
          onPrev: _currentIndex > 0 ? () => _goTo(_currentIndex - 1) : null,
          onNext: _currentIndex < _gpsMedia.length - 1 ? () => _goTo(_currentIndex + 1) : null,
          onFitAll: _fitAllPoints,
        ),
      ],
    );
  }
}

class _RouteNavPanel extends StatelessWidget {
  final CommunityMediaItem item;
  final int index;
  final int total;
  final String dayLabel;
  final String timeLabel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onFitAll;

  const _RouteNavPanel({
    required this.item,
    required this.index,
    required this.total,
    required this.dayLabel,
    required this.timeLabel,
    required this.onPrev,
    required this.onNext,
    required this.onFitAll,
  });

  @override
  Widget build(BuildContext context) {
    final imgUrl = item.thumbnailUrl ?? item.downloadUrl;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left,
                color: onPrev != null ? AppColors.textOnLight : Colors.grey.shade300, size: 28),
            onPressed: onPrev,
            padding: EdgeInsets.zero,
          ),
          // 썸네일
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Image.network(imgUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.photo_outlined, color: AppColors.textSub))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dayLabel.isNotEmpty)
                  Text(dayLabel,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.bold)),
                Text('${index + 1} / $total',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textOnLight)),
                if (timeLabel.isNotEmpty)
                  Text(timeLabel,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSub)),
              ],
            ),
          ),
          // 전체 경로 보기 버튼
          IconButton(
            icon: const Icon(Icons.fit_screen, size: 20, color: AppColors.textSub),
            tooltip: '전체 경로 보기',
            onPressed: onFitAll,
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: Icon(Icons.chevron_right,
                color: onNext != null ? AppColors.textOnLight : Colors.grey.shade300, size: 28),
            onPressed: onNext,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

// ── 전체 댓글 바텀시트 ────────────────────────────────────────────────────────

class _CommentSheet extends StatefulWidget {
  final ApiService api;
  final int tripId;
  final ValueChanged<int> onCountChanged;

  const _CommentSheet({
    required this.api,
    required this.tripId,
    required this.onCountChanged,
  });

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final List<CommunityCommentResponse> _comments = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _sending = false;

  // 수정 중인 댓글 ID (null이면 신규 작성 모드)
  int? _editingCommentId;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await widget.api.fetchCommunityComments(widget.tripId);
      if (mounted) setState(() { _comments
        ..clear()
        ..addAll(comments);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorSnackBar(context, '댓글 로드 실패: $e');
      }
    }
  }

  Future<void> _submit() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      if (_editingCommentId != null) {
        // 수정
        final updated = await widget.api.updateCommunityComment(
            widget.tripId, _editingCommentId!, text);
        final idx = _comments.indexWhere((c) => c.id == _editingCommentId);
        if (idx >= 0 && mounted) {
          setState(() {
            _comments[idx] = updated;
            _editingCommentId = null;
          });
        }
      } else {
        // 신규 작성
        final added = await widget.api.addCommunityComment(widget.tripId, text);
        if (mounted) {
          setState(() => _comments.add(added));
          widget.onCountChanged(1);
          // 맨 아래로 스크롤
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
      _inputController.clear();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '오류: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startEdit(CommunityCommentResponse comment) {
    setState(() {
      _editingCommentId = comment.id;
      _inputController.text = comment.content;
    });
    // 입력창에 포커스
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelEdit() {
    setState(() {
      _editingCommentId = null;
      _inputController.clear();
    });
  }

  Future<void> _delete(CommunityCommentResponse comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.destructive)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.api.deleteCommunityComment(widget.tripId, comment.id);
      if (mounted) {
        setState(() => _comments.removeWhere((c) => c.id == comment.id));
        widget.onCountChanged(-1);
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '삭제 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 8),
              // 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text('댓글 ${_comments.length}개',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textOnLight)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 댓글 목록
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                    : _comments.isEmpty
                        ? const EmptyState(icon: Icons.chat_bubble_outline, title: '아직 댓글이 없습니다.',
                            subtitle: '첫 번째 댓글을 남겨보세요!')
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _comments.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                            itemBuilder: (_, i) => _CommentItem(
                              comment: _comments[i],
                              onEdit: () => _startEdit(_comments[i]),
                              onDelete: () => _delete(_comments[i]),
                            ),
                          ),
              ),
              const Divider(height: 1),
              // 수정 모드 표시
              if (_editingCommentId != null)
                Container(
                  color: AppColors.background,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 14, color: AppColors.accent),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text('댓글 수정 중', style: TextStyle(fontSize: 12, color: AppColors.accent)),
                      ),
                      GestureDetector(
                        onTap: _cancelEdit,
                        child: const Icon(Icons.close, size: 16, color: AppColors.textSub),
                      ),
                    ],
                  ),
                ),
              // 입력창
              Padding(
                padding: EdgeInsets.only(
                  left: 12, right: 12, top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: '댓글을 입력하세요...',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        textInputAction: TextInputAction.newline,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _inputController.text.trim().isEmpty ? null : _submit,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _inputController.text.trim().isEmpty
                              ? Colors.grey.shade300
                              : AppColors.accent,
                        ),
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Icon(
                                _editingCommentId != null ? Icons.check : Icons.send,
                                color: Colors.white,
                                size: 18,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommentItem extends StatelessWidget {
  final CommunityCommentResponse comment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CommentItem({required this.comment, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryDark,
            child: Text(comment.nickname.isNotEmpty ? comment.nickname[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.nickname,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textOnLight)),
                    const SizedBox(width: 8),
                    Text(_relativeTime(comment.createdAt),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSub)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.content, style: const TextStyle(fontSize: 14, color: AppColors.textOnLight)),
              ],
            ),
          ),
          if (comment.isMine) ...[
            GestureDetector(
              onTap: onEdit,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.edit_outlined, size: 16, color: AppColors.textSub),
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.delete_outline, size: 16, color: AppColors.destructive),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _relativeTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }
}
