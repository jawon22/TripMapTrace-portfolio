import 'package:flutter/material.dart';

import '../main.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/empty_state.dart';
import '../widgets/fullscreen_viewer.dart';

enum _MediaFilter { all, photo, video }

class TimelineTab extends StatefulWidget {
  final ApiService api;
  final int tripId;
  final String myRole;

  const TimelineTab(
      {super.key,
      required this.api,
      required this.tripId,
      required this.myRole});

  @override
  State<TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends State<TimelineTab> {
  List<MediaItem> _items = [];
  bool _loading = false;
  String? _errorMessage;
  bool _selecting = false;
  final Set<int> _selectedIds = {};
  bool _downloading = false;
  bool _deleting = false;
  bool _settingCover = false;
  _MediaFilter _filter = _MediaFilter.all;

  @override
  void initState() {
    super.initState();
    _fetchList();
  }

  Future<void> _fetchList() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final items = await widget.api.fetchMedia(widget.tripId);
      items.sort((a, b) {
        final at = a.takenAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        final bt = b.takenAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        final cmp = at.compareTo(bt);
        return cmp != 0 ? cmp : a.id.compareTo(b.id);
      });
      setState(() => _items = items);
    } catch (e) {
      setState(() => _errorMessage = '목록을 불러오지 못했습니다: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  List<MediaItem> get _visibleItems {
    switch (_filter) {
      case _MediaFilter.photo:
        return _items.where((i) => i.type == 'PHOTO').toList();
      case _MediaFilter.video:
        return _items.where((i) => i.type == 'VIDEO').toList();
      case _MediaFilter.all:
        return _items;
    }
  }

  void _selectAll() =>
      setState(() => _selectedIds.addAll(_visibleItems.map((e) => e.id)));

  void _exitSelect() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  Future<void> _setCover() async {
    if (_selectedIds.length != 1 || _settingCover) return;
    final mediaId = _selectedIds.first;
    setState(() => _settingCover = true);
    try {
      await widget.api.setTripCover(widget.tripId, mediaId);
      tripListRefreshNotifier.value++;
      if (mounted) {
        _exitSelect();
        showSuccessSnackBar(context, '커버 이미지로 지정했습니다.');
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '커버 지정 실패: $e');
    } finally {
      if (mounted) setState(() => _settingCover = false);
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty || _deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('미디어 삭제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('선택한 ${_selectedIds.length}개를 삭제하시겠습니까?'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('삭제'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    int success = 0;
    int fail = 0;
    for (final id in List<int>.from(_selectedIds)) {
      try {
        await widget.api.deleteMedia(widget.tripId, id);
        success++;
      } catch (_) {
        fail++;
      }
    }
    setState(() => _deleting = false);
    _exitSelect();
    await _fetchList();

    if (mounted) {
      if (fail == 0) {
        showSuccessSnackBar(context, '$success개 삭제 완료');
      } else {
        showErrorSnackBar(context, '$success개 삭제 완료, $fail개 실패');
      }
    }
  }

  Future<void> _downloadSelected() async {
    if (_selectedIds.isEmpty || _downloading) return;
    setState(() => _downloading = true);

    int success = 0;
    int fail = 0;

    for (final id in List<int>.from(_selectedIds)) {
      final item = _items.firstWhere((i) => i.id == id);
      try {
        final url = await widget.api.getDownloadUrl(widget.tripId, id);
        await saveUrlToGallery(url: url, isVideo: item.type == 'VIDEO', id: id);
        success++;
      } catch (e) {
        fail++;
      }
    }

    setState(() => _downloading = false);
    _exitSelect();

    if (mounted) {
      if (fail == 0) {
        showSuccessSnackBar(context, '$success개 저장 완료');
      } else {
        showErrorSnackBar(context, '$success개 저장 완료, $fail개 실패');
      }
    }
  }

  void _openFullscreen(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenViewer(
          items: _visibleItems,
          initialIndex: index,
          api: widget.api,
          tripId: widget.tripId,
          canDownload: widget.myRole != 'VIEWER',
          onItemChanged: (updated) {
            setState(() {
              final idx = _items.indexWhere((e) => e.id == updated.id);
              if (idx != -1) _items[idx] = updated;
            });
          },
        ),
      ),
    );
  }

  // ── Date grouping ─────────────────────────────────

  String _dateKey(MediaItem item) {
    if (item.takenAt == null) return '날짜 미상';
    final d = item.takenAt!.toLocal();
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  /// Returns a flat list of either String (date header) or List of MediaItem? (3-col row)
  List<dynamic> _buildSections() {
    final visible = _visibleItems;
    if (visible.isEmpty) return [];

    final grouped = <String, List<MediaItem>>{};
    final orderedKeys = <String>[];

    for (final item in visible) {
      final key = _dateKey(item);
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
        orderedKeys.add(key);
      }
      grouped[key]!.add(item);
    }

    final result = <dynamic>[];
    for (final key in orderedKeys) {
      result.add(key);
      final items = grouped[key]!;
      for (int i = 0; i < items.length; i += 3) {
        result.add([
          items[i],
          i + 1 < items.length ? items[i + 1] : null,
          i + 2 < items.length ? items[i + 2] : null,
        ]);
      }
    }
    return result;
  }

  // ── Header ────────────────────────────────────────

  Widget _buildHeader() {
    final visible = _visibleItems;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Text(
            '${visible.length}개'
            '${_selecting && _selectedIds.isNotEmpty ? ' · ${_selectedIds.length}개 선택됨' : ''}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSub),
          ),
          const Spacer(),
          if (_selecting) ...[
            // 실제 액션(커버/다운로드/삭제)은 라벨이 있는 하단 바로 이동했다.
            // 상단엔 전체선택과 닫기만 남겨 아이콘 의미 혼동을 없앤다.
            TextButton(
              onPressed: _selectAll,
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('전체선택'),
            ),
            IconButton(
              onPressed: _exitSelect,
              icon: const Icon(Icons.close),
              tooltip: '선택 취소',
            ),
          ] else ...[
            if (widget.myRole != 'VIEWER')
              IconButton(
                onPressed: () => setState(() => _selecting = true),
                icon: const Icon(Icons.download_outlined),
                tooltip: '다운로드',
              ),
            IconButton(
              onPressed: _fetchList,
              icon: const Icon(Icons.refresh),
              tooltip: '새로고침',
            ),
          ],
        ],
      ),
    );
  }

  // ── Filter chips ──────────────────────────────────

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Row(
        children: [
          _filterChip('전체', _MediaFilter.all),
          const SizedBox(width: 6),
          _filterChip('사진', _MediaFilter.photo),
          const SizedBox(width: 6),
          _filterChip('영상', _MediaFilter.video),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _MediaFilter filter) {
    final selected = _filter == filter;
    return GestureDetector(
      onTap: () {
        if (_filter != filter) {
          setState(() {
            _filter = filter;
            _exitSelect();
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? Colors.white : AppColors.textSub,
          ),
        ),
      ),
    );
  }

  // ── Grid ─────────────────────────────────────────

  Widget _buildThumbnail(MediaItem item) {
    final isVideo = item.type == 'VIDEO';
    final url = item.thumbnailUrl ?? (isVideo ? null : item.downloadUrl);
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image, color: Colors.black38),
        ),
      );
    }
    return Container(
      color: isVideo ? Colors.black12 : Colors.grey.shade200,
      child: Icon(
        isVideo ? Icons.videocam : Icons.photo,
        color: Colors.black38,
      ),
    );
  }

  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            date,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textOnLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaRow(MediaItem a, MediaItem? b, MediaItem? c) {
    final visible = _visibleItems;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Expanded(child: _buildGridCell(a, visible.indexOf(a))),
          const SizedBox(width: 3),
          Expanded(
            child: b != null
                ? _buildGridCell(b, visible.indexOf(b))
                : const SizedBox(),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: c != null
                ? _buildGridCell(c, visible.indexOf(c))
                : const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCell(MediaItem item, int index) {
    final isSelected = _selectedIds.contains(item.id);
    final isVideo = item.type == 'VIDEO';

    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        onTap: () {
          if (_selecting) {
            _toggleSelect(item.id);
          } else {
            _openFullscreen(index);
          }
        },
        onLongPress: () {
          if (!_selecting) {
            setState(() {
              _selecting = true;
              _selectedIds.add(item.id);
            });
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildThumbnail(item),
            if (_selecting)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent : Colors.black38,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
            if (isVideo)
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow,
                        size: 22, color: Colors.white),
                  ),
                ),
              ),
            if (!_selecting)
              Positioned(
                left: 4,
                right: 4,
                bottom: 4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (item.commentCount > 0)
                      _CompactCount(
                        icon: Icons.chat_bubble_outline,
                        count: item.commentCount,
                      ),
                    const Spacer(),
                    LikeButton(
                      key: ValueKey('like_${item.id}'),
                      mediaId: item.id,
                      tripId: widget.tripId,
                      likeCount: item.likeCount,
                      isLiked: item.isLiked,
                      api: widget.api,
                      onChanged: (updated) {
                        final idx = _items.indexWhere((e) => e.id == updated.id);
                        if (idx != -1) _items[idx] = updated;
                      },
                      compact: true,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedList() {
    final sections = _buildSections();
    return RefreshIndicator(
      onRefresh: _fetchList,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        itemCount: sections.length,
        itemBuilder: (context, i) {
          final section = sections[i];
          if (section is String) {
            return _buildDateHeader(section);
          }
          final row = section as List;
          return _buildMediaRow(
            row[0] as MediaItem,
            row[1] as MediaItem?,
            row[2] as MediaItem?,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;
    return Column(
      children: [
        _buildHeader(),
        _buildFilterChips(),
        if (_loading && _items.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_errorMessage != null && _items.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: _fetchList, child: const Text('다시 시도')),
                  ],
                ),
              ),
            ),
          )
        else if (visible.isEmpty)
          Expanded(
            child: EmptyState(
              icon: Icons.photo_library_outlined,
              title: _filter == _MediaFilter.all
                  ? '업로드된 미디어가 없어요'
                  : _filter == _MediaFilter.photo
                      ? '사진이 없어요'
                      : '영상이 없어요',
              subtitle: _filter == _MediaFilter.all
                  ? '사진이나 영상을 업로드해보세요'
                  : '다른 필터를 선택해보세요',
            ),
          )
        else
          Expanded(child: _buildGroupedList()),
        // 선택모드 하단 액션 바 (VIEWER는 가능한 액션이 없어 숨김)
        if (_selecting && widget.myRole != 'VIEWER') _buildSelectionBar(),
      ],
    );
  }

  // ── Selection action bar ──────────────────────────

  Widget _buildSelectionBar() {
    final hasSelection = _selectedIds.isNotEmpty;
    final canCover =
        widget.myRole == 'OWNER' && _selectedIds.length == 1 && !_settingCover;
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (widget.myRole == 'OWNER')
                _selectionAction(
                  icon: Icons.image_outlined,
                  label: '커버 지정',
                  enabled: canCover,
                  loading: _settingCover,
                  onTap: _setCover,
                ),
              _selectionAction(
                icon: Icons.download,
                label: '다운로드',
                enabled: hasSelection && !_downloading,
                loading: _downloading,
                onTap: _downloadSelected,
              ),
              _selectionAction(
                icon: Icons.delete_outline,
                label: '삭제',
                enabled: hasSelection && !_deleting,
                loading: _deleting,
                destructive: true,
                onTap: _deleteSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectionAction({
    required IconData icon,
    required String label,
    required bool enabled,
    required bool loading,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final Color color = !enabled
        ? Colors.grey.shade400
        : destructive
            ? AppColors.destructive
            : AppColors.textOnLight;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Compact count badge ────────────────────────────────────────────────────────

class _CompactCount extends StatelessWidget {
  final IconData icon;
  final int count;

  const _CompactCount({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 3),
          Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}
