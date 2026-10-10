import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/media_item.dart';
import '../models/trip.dart';
import '../models/user_stats.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import 'account_settings_screen.dart';
import 'login_screen.dart';
import 'trip_detail_screen.dart';
import '../widgets/fullscreen_viewer.dart';

class ProfileTab extends StatefulWidget {
  final VoidCallback? onNavigateToHome;
  final bool isActive;
  final int unreadCount;
  final VoidCallback? onBellTap;

  const ProfileTab({
    super.key,
    this.onNavigateToHome,
    this.isActive = false,
    this.unreadCount = 0,
    this.onBellTap,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _api = ApiService();
  final _auth = AuthService();

  String? _nickname;
  String? _profileImageUrl;
  String? _provider;
  UserStats? _stats;
  List<Trip> _recentTrips = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final cachedNickname = await _auth.getNickname();
      if (mounted) setState(() => _nickname = cachedNickname);

      final results = await Future.wait([
        _api.fetchMe(),
        _api.fetchUserStats(),
        _api.fetchTrips(),
      ]);
      final me = results[0] as Map<String, dynamic>;
      final stats = results[1] as UserStats;
      final trips = results[2] as List<Trip>;

      if (mounted) {
        setState(() {
          _nickname = me['nickname'] as String? ?? cachedNickname;
          _profileImageUrl = me['profileImageUrl'] as String?;
          _provider = me['provider'] as String?;
          _stats = stats;
          _recentTrips = (trips..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
              .take(3)
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final fileName = picked.name;
      final contentType = 'image/jpeg';

      final presign = await _api.presignAvatar(
        originalFileName: fileName,
        contentType: contentType,
      );

      await _api.putToS3(presign.uploadUrl, bytes, contentType);

      final result = await _api.completeAvatar(presign.storageKey);
      final newUrl = result['profileImageUrl'] as String?;

      await _auth.updateProfileImageUrl(newUrl);

      if (mounted) setState(() => _profileImageUrl = newUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필 사진 업로드에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필'),
        actions: [
          IconButton(
            icon: _buildBellIcon(widget.unreadCount),
            onPressed: widget.onBellTap,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildAvatar(),
                  const SizedBox(height: 16),
                  _buildUserInfo(),
                  const SizedBox(height: 24),
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  _buildMyTripsSection(),
                  const SizedBox(height: 24),
                  _buildSettingsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    final initial = (_nickname?.isNotEmpty == true)
        ? _nickname![0].toUpperCase()
        : '?';

    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: _uploading ? null : _pickAndUploadAvatar,
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: _profileImageUrl != null
                  ? NetworkImage(_profileImageUrl!)
                  : null,
              child: _profileImageUrl == null
                  ? Text(
                      initial,
                      style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    )
                  : null,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: _uploading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 14, color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Center(
      child: Text(
        _nickname ?? '닉네임 없음',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildStatsRow() {
    final stats = _stats;
    return Row(
      children: [
        _buildStatCard('여행', stats?.tripCount ?? 0, Icons.map_outlined),
        const SizedBox(width: 12),
        _buildStatCard('미디어', stats?.mediaCount ?? 0, Icons.photo_outlined,
            onTap: _openMyMediaSheet),
      ],
    );
  }

  void _openMyMediaSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MyMediaSheet(api: _api),
    );
  }

  Widget _buildMyTripsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '참여 중인 여행',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            TextButton(
              onPressed: widget.onNavigateToHome,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('전체 보기',
                  style: TextStyle(fontSize: 13, color: AppColors.accent)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: _recentTrips.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('참여 중인 여행이 없어요',
                        style: TextStyle(color: AppColors.textSub, fontSize: 13)),
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < _recentTrips.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _buildTripTile(_recentTrips[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTripTile(Trip trip) {
    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)),
      ).then((_) => _load()),
      title: Text(
        trip.title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _roleBadge(trip.myRole),
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

  Widget _buildStatCard(String label, int value, IconData icon,
      {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(icon, size: 24, color: AppColors.accent),
                const SizedBox(height: 8),
                Text(
                  '$value',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSub)),
                    if (onTap != null) ...[
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right,
                          size: 14, color: AppColors.textSub),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '계정 설정',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSub,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('계정 관리'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AccountSettingsScreen(
                    currentNickname: _nickname,
                    provider: _provider,
                  ),
                ),
              );
              _load();
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.destructive),
            title: const Text('로그아웃',
                style: TextStyle(color: AppColors.destructive)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}

// ── 나의 미디어 갤러리 바텀시트 ─────────────────────────────────────────────────

class _MyMediaSheet extends StatefulWidget {
  final ApiService api;
  const _MyMediaSheet({required this.api});

  @override
  State<_MyMediaSheet> createState() => _MyMediaSheetState();
}

class _MyMediaSheetState extends State<_MyMediaSheet> {
  List<MediaItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.api.fetchMyMedia();
      if (mounted) setState(() => _items = items);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openFullscreen(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenViewer(
          items: _items,
          initialIndex: index,
          showNickname: false,
          canDownload: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '나의 미디어',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(
                          child: Text('업로드한 미디어가 없어요',
                              style: TextStyle(
                                  color: AppColors.textSub, fontSize: 14)),
                        )
                      : GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(3),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 3,
                            mainAxisSpacing: 3,
                          ),
                          itemCount: _items.length,
                          itemBuilder: (_, index) =>
                              _buildCell(_items[index], index),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(MediaItem item, int index) {
    final isVideo = item.type == 'VIDEO';
    final url = item.thumbnailUrl ?? (isVideo ? null : item.downloadUrl);

    return GestureDetector(
      onTap: () => _openFullscreen(index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          url != null
              ? Image.network(url, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image,
                            color: Colors.black38),
                      ))
              : Container(
                  color: isVideo ? Colors.black12 : Colors.grey.shade200,
                  child: Icon(
                    isVideo ? Icons.videocam : Icons.photo,
                    color: Colors.black38,
                  ),
                ),
          if (isVideo)
            Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.play_arrow, size: 20, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
