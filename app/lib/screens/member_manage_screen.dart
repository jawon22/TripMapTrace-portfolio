import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/invite_bottom_sheet.dart';
import '../widgets/invite_search_sheet.dart';

class MemberManageScreen extends StatefulWidget {
  final ApiService api;
  final int tripId;
  final bool isOwner;

  const MemberManageScreen({
    super.key,
    required this.api,
    required this.tripId,
    required this.isOwner,
  });

  @override
  State<MemberManageScreen> createState() => _MemberManageScreenState();
}

class _MemberManageScreenState extends State<MemberManageScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = false;
  int? _myUserId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myUserId = await AuthService().getUserId();
    await _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    setState(() => _loading = true);
    try {
      final members = await widget.api.fetchMembers(widget.tripId);
      setState(() => _members = members);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, '멤버 목록 로드 실패: $e');
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showInviteSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => InviteBottomSheet(
        api: widget.api,
        tripId: widget.tripId,
      ),
    );
  }

  void _showInviteSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => InviteSearchSheet(
        api: widget.api,
        tripId: widget.tripId,
      ),
    ).then((_) => _fetchMembers());
  }

  Future<void> _changeRole(int memberId, String currentRole) async {
    final roles = ['EDITOR', 'VIEWER'];
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('역할 변경'),
        children: roles.map((role) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, role),
            child: Row(
              children: [
                _roleIcon(role),
                const SizedBox(width: 8),
                Text(role),
                if (role == currentRole) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check, size: 16, color: AppColors.accent),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (selected == null || selected == currentRole) return;

    try {
      await widget.api.changeMemberRole(widget.tripId, memberId, selected);
      await _fetchMembers();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, '역할 변경 실패: $e');
      }
    }
  }

  Future<void> _removeMember(int memberId, String nickname) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('멤버 삭제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$nickname 을(를) 삭제하시겠습니까?'),
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
      await widget.api.removeMember(widget.tripId, memberId);
      await _fetchMembers();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, '멤버 삭제 실패: $e');
      }
    }
  }

  Future<void> _leaveTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('여행 탈퇴'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('이 여행에서 탈퇴하시겠습니까?'),
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
                      child: const Text('탈퇴'),
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
      await widget.api.leaveTrip(widget.tripId);
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('탈퇴 완료'),
          content: const Text('여행에서 탈퇴되었습니다.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, '탈퇴 실패: $e');
      }
    }
  }

  // ── Widgets ───────────────────────────────────────

  Icon _roleIcon(String role) {
    final color = switch (role) {
      'OWNER' => AppColors.roleOwner,
      'EDITOR' => AppColors.roleEditor,
      _ => AppColors.roleViewer,
    };
    final icon = switch (role) {
      'OWNER' => Icons.star,
      'EDITOR' => Icons.edit_outlined,
      _ => Icons.visibility_outlined,
    };
    return Icon(icon, size: 16, color: color);
  }

  Widget _roleChip(String role) {
    final color = switch (role) {
      'OWNER' => AppColors.roleOwner,
      'EDITOR' => AppColors.roleEditor,
      _ => AppColors.roleViewer,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _roleIcon(role),
          const SizedBox(width: 4),
          Text(role, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? profileImageUrl, String nickname, String role, bool isMe) {
    final initial = nickname.isNotEmpty ? nickname[0].toUpperCase() : '?';
    final isOwner = role == 'OWNER';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
              ? NetworkImage(profileImageUrl)
              : null,
          child: profileImageUrl == null || profileImageUrl.isEmpty
              ? Text(
                  initial,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                )
              : null,
        ),
        if (isOwner)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star, size: 10, color: Colors.white),
            ),
          ),
        if (isMe)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.roleEditor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '나',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('멤버 관리'),
        actions: [
          if (!widget.isOwner)
            TextButton(
              onPressed: _leaveTrip,
              child: const Text('탈퇴',
                  style: TextStyle(color: AppColors.destructive)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchMembers,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final m = _members[index];
                  final memberId = m['memberId'] as int;
                  final userId = m['userId'] as int?;
                  final nickname = m['nickname'] as String? ?? '닉네임 없음';
                  final profileImageUrl = m['profileImageUrl'] as String?;
                  final role = m['role'] as String;
                  final isOwnerRow = role == 'OWNER';
                  final isMe = userId != null && userId == _myUserId;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    leading: _buildAvatar(profileImageUrl, nickname, role, isMe),
                    title: Text(
                      nickname,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _roleChip(role),
                    ),
                    isThreeLine: true,
                    trailing: widget.isOwner && !isOwnerRow
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.swap_horiz),
                                tooltip: '역할 변경',
                                onPressed: () => _changeRole(memberId, role),
                              ),
                              IconButton(
                                icon: const Icon(Icons.person_remove_outlined),
                                tooltip: '멤버 삭제',
                                onPressed: () =>
                                    _removeMember(memberId, nickname),
                              ),
                            ],
                          )
                        : null,
                  );
                },
              ),
            ),
      // 초대 코드 버튼 하단 고정 (OWNER only)
      bottomNavigationBar: widget.isOwner
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _showInviteSearchSheet,
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('사용자 초대'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showInviteSheet,
                        icon: const Icon(Icons.link),
                        label: const Text('초대 링크'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
