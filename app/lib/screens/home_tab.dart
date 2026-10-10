import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/received_invitation.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/empty_state.dart';
import 'create_trip_screen.dart';
import 'trip_detail_screen.dart';

class HomeTab extends StatefulWidget {
  final bool isActive;
  final int unreadCount;
  final VoidCallback? onBellTap;

  const HomeTab({
    super.key,
    required this.isActive,
    this.unreadCount = 0,
    this.onBellTap,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final ApiService _api = ApiService();
  List<Trip> _trips = [];
  List<ReceivedInvitation> _invitations = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshAll();
    tripListRefreshNotifier.addListener(_refreshAll);
  }

  @override
  void didUpdateWidget(HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _refreshAll();
    }
  }

  @override
  void dispose() {
    tripListRefreshNotifier.removeListener(_refreshAll);
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([_fetchTrips(), _fetchInvitations()]);
  }

  Future<void> _fetchInvitations() async {
    try {
      final invitations = await _api.fetchMyInvitations();
      if (mounted) setState(() => _invitations = invitations);
    } catch (_) {
      // 초대 목록 실패는 조용히 무시 (여행 목록은 정상 표시)
    }
  }

  Future<void> _acceptInvitation(ReceivedInvitation inv) async {
    try {
      await _api.acceptInvitation(inv.id);
      if (mounted) {
        setState(() => _invitations.removeWhere((e) => e.id == inv.id));
        showSuccessSnackBar(context, '\'${inv.tripTitle}\' 여행에 참여했습니다!');
      }
      await _fetchTrips();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '수락에 실패했습니다.');
    }
  }

  Future<void> _declineInvitation(ReceivedInvitation inv) async {
    try {
      await _api.declineInvitation(inv.id);
      if (mounted) {
        setState(() => _invitations.removeWhere((e) => e.id == inv.id));
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '거절에 실패했습니다.');
    }
  }

  Future<void> _showJoinDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('여행 참여'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: '초대 코드를 입력하세요'),
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
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
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('참여'),
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
    final raw = controller.text.trim();
    // URL 형태로 붙여넣기 해도 토큰만 추출 (예: tripmaptrace://invite/ABC123 → ABC123)
    final token = raw.contains('/') ? raw.split('/').last : raw;
    if (token.isEmpty) return;

    try {
      await _api.joinByToken(token);
      await _fetchTrips();
      if (mounted) {
        showSuccessSnackBar(context, '여행에 참여했습니다.');
      }
    } catch (e) {
      if (mounted) {
        String message = '참여 실패';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null) {
            message = data['message'] as String;
          }
        }
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('참여 불가'),
            content: Text(message),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _fetchTrips() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trips = await _api.fetchTrips();
      setState(() => _trips = trips);
    } catch (e) {
      setState(() => _error = '목록을 불러오지 못했습니다: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showFabMenu() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('새 여행 만들기'),
              onTap: () => Navigator.pop(ctx, 'create'),
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: const Text('초대 코드로 참여'),
              onTap: () => Navigator.pop(ctx, 'join'),
            ),
          ],
        ),
      ),
    );

    if (selected == 'create') _navigateToCreate();
    if (selected == 'join') _showJoinDialog();
  }

  void _navigateToCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTripScreen()),
    );
  }

  Future<void> _showEditDialog(Trip trip) async {
    final controller = TextEditingController(text: trip.title);
    DateTime? startDate = trip.startDate;
    DateTime? endDate = trip.endDate;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('여행 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: '여행 이름'),
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 8),
              _buildDateRow(
                ctx,
                label: '시작일',
                date: startDate,
                onPick: (d) => setDialogState(() => startDate = d),
                onClear: () => setDialogState(() => startDate = null),
              ),
              const SizedBox(height: 4),
              _buildDateRow(
                ctx,
                label: '종료일',
                date: endDate,
                onPick: (d) => setDialogState(() => endDate = d),
                onClear: () => setDialogState(() => endDate = null),
              ),
              const SizedBox(height: 20),
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
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('저장'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    final title = controller.text.trim();
    if (title.isEmpty) return;

    try {
      await _api.updateTrip(trip.id, title,
          startDate: startDate, endDate: endDate);
      await _fetchTrips();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, '수정 실패: $e');
      }
    }
  }

  Widget _buildDateRow(
    BuildContext ctx, {
    required String label,
    required DateTime? date,
    required ValueChanged<DateTime> onPick,
    required VoidCallback onClear,
  }) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
        const SizedBox(width: 8),
        Expanded(
          child: TextButton(
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: date ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) onPick(picked);
            },
            child: Text(
              date != null ? _formatDate(date) : '날짜 선택',
              style: TextStyle(
                fontSize: 13,
                color:
                    date != null ? AppColors.textOnLight : AppColors.textSub,
              ),
            ),
          ),
        ),
        if (date != null)
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: onClear,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
      ],
    );
  }

  Future<void> _deleteTrip(Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('여행 삭제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${trip.title}" 여행을 삭제하시겠습니까?\n모든 미디어도 함께 삭제됩니다.'),
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

    try {
      await _api.deleteTrip(trip.id);
      await _fetchTrips();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, '삭제 실패: $e');
      }
    }
  }

  Future<void> _toggleVisibility(Trip trip) async {
    try {
      final updated = await _api.setTripVisibility(trip.id, isPublic: !trip.isPublic);
      final label = updated.isPublic ? '공개' : '비공개';
      if (mounted) showSuccessSnackBar(context, '"${updated.title}" 여행이 $label로 설정되었습니다.');
      await _fetchTrips();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '설정 변경 실패: $e');
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  String _formatPeriod(DateTime? start, DateTime? end) {
    if (start == null) return '';
    final s = _formatDate(start);
    if (end == null || _formatDate(end) == s) return s;
    return '$s ~ ${_formatDate(end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.location_on, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text('TripMapTrace'),
          ],
        ),
        actions: [
          IconButton(
            icon: _buildBellIcon(widget.unreadCount),
            onPressed: widget.onBellTap,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFabMenu,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        tooltip: '여행 추가',
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBellIcon(int count) {
    if (count == 0) return const Icon(Icons.notifications_outlined);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_outlined),
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 16),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    final empty = _trips.isEmpty && _invitations.isEmpty;
    if (_loading && empty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && empty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _refreshAll, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }
    if (empty) {
      return EmptyState(
        icon: Icons.map_outlined,
        title: '아직 여행이 없어요',
        subtitle: '첫 여행을 만들어 동행자와 추억을 기록해보세요!',
        actionLabel: '새 여행 만들기',
        onAction: _navigateToCreate,
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_invitations.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.mark_email_unread_outlined,
                    size: 18, color: AppColors.accent),
                const SizedBox(width: 6),
                Text('받은 초대 ${_invitations.length}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            ..._invitations.map((inv) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildInvitationCard(inv),
                )),
            if (_trips.isNotEmpty) ...[
              const Divider(height: 24),
            ],
          ],
          for (final trip in _trips) ...[
            _buildTripCard(trip),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildInvitationCard(ReceivedInvitation inv) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                  child: const Icon(Icons.card_travel, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inv.tripTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${inv.inviterNickname}님의 초대 · 멤버 ${inv.memberCount}명',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSub)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _declineInvitation(inv),
                    child: const Text('거절'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _acceptInvitation(inv),
                    child: const Text('수락'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)),
        ).then((_) => _fetchTrips()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image + overlay
            SizedBox(
              height: 145,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover image or placeholder
                  trip.coverThumbnailUrl != null
                      ? Image.network(
                          trip.coverThumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _coverPlaceholder(),
                        )
                      : _coverPlaceholder(),
                  // Gradient overlay
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                  // Role badge top-left
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _roleBadge(trip.myRole),
                  ),
                  // Menu top-right (OWNER only)
                  if (trip.isOwner)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: PopupMenuButton<String>(
                        color: Colors.white,
                        onSelected: (value) {
                          if (value == 'edit') _showEditDialog(trip);
                          if (value == 'delete') _deleteTrip(trip);
                          if (value == 'visibility') _toggleVisibility(trip);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('이름 수정')),
                          PopupMenuItem(
                            value: 'visibility',
                            child: Row(
                              children: [
                                Icon(
                                  trip.isPublic ? Icons.lock_outline : Icons.public,
                                  size: 16,
                                  color: AppColors.textOnLight,
                                ),
                                const SizedBox(width: 8),
                                Text(trip.isPublic ? '비공개로 변경' : '공개로 변경'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('삭제', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                        // 밝은 커버 사진 위에서도 보이도록 반투명 어두운 원형 배경을 깐다.
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  // Trip title bottom
                  Positioned(
                    bottom: 8,
                    left: 12,
                    right: 40,
                    child: Text(
                      trip.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Info bar — 날짜는 보조(회색), 멤버·미디어 수는 강조(굵게)로 위계를 나눔
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  if (trip.startDate != null) ...[
                    const Icon(Icons.calendar_today_outlined,
                        size: 13, color: AppColors.textSub),
                    const SizedBox(width: 4),
                    Text(
                      _formatPeriod(trip.startDate, trip.endDate),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSub),
                    ),
                  ],
                  const Spacer(),
                  const Icon(Icons.group_outlined, size: 14, color: AppColors.textSub),
                  const SizedBox(width: 4),
                  Text(
                    '${trip.memberCount}명',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOnLight),
                  ),
                  const SizedBox(width: 14),
                  const Icon(Icons.photo_library_outlined,
                      size: 14, color: AppColors.textSub),
                  const SizedBox(width: 4),
                  Text(
                    '${trip.mediaCount}개',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOnLight),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      color: AppColors.primary,
      child: const Center(
        child: Icon(Icons.map_outlined, size: 48, color: AppColors.textSub),
      ),
    );
  }

  Widget _roleBadge(String role) {
    final color = switch (role) {
      'OWNER' => AppColors.roleOwner,
      'EDITOR' => AppColors.roleEditor,
      _ => AppColors.roleViewer,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
