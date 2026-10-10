import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  final String? currentNickname;
  final String? provider;

  const AccountSettingsScreen({super.key, this.currentNickname, this.provider});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late String? _nickname;

  bool _notifyUpload = true;
  bool _notifyJoin = true;
  bool _notifyRoleChange = true;
  bool _notifSettingsLoaded = false;

  final _api = ApiService();
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _nickname = widget.currentNickname;
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final data = await _api.fetchNotificationSettings();
      if (mounted) {
        setState(() {
          _notifyUpload = data['notifyUpload'] as bool? ?? true;
          _notifyJoin = data['notifyJoin'] as bool? ?? true;
          _notifyRoleChange = data['notifyRoleChange'] as bool? ?? true;
          _notifSettingsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _notifSettingsLoaded = true);
    }
  }

  Future<void> _updateNotificationSettings() async {
    try {
      await _api.updateNotificationSettings(
        notifyUpload: _notifyUpload,
        notifyJoin: _notifyJoin,
        notifyRoleChange: _notifyRoleChange,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림 설정 저장에 실패했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('계정 관리')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          const _SectionHeader(label: '프로필'),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('닉네임 수정'),
            subtitle: Text(_nickname ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNicknameDialog(context),
          ),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const _SectionHeader(label: '알림'),
          if (!_notifSettingsLoaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else ...[
            SwitchListTile(
              secondary: const Icon(Icons.photo_library_outlined),
              title: const Text('업로드 알림'),
              subtitle: const Text('멤버가 사진/영상을 올리면 알림'),
              value: _notifyUpload,
              onChanged: (v) {
                setState(() => _notifyUpload = v);
                _updateNotificationSettings();
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.group_add_outlined),
              title: const Text('참여/탈퇴 알림'),
              subtitle: const Text('멤버가 여행에 참여하거나 탈퇴하면 알림'),
              value: _notifyJoin,
              onChanged: (v) {
                setState(() => _notifyJoin = v);
                _updateNotificationSettings();
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.manage_accounts_outlined),
              title: const Text('역할/강퇴/여행 삭제 알림'),
              subtitle: const Text('역할 변경, 강퇴, 여행 삭제 시 알림'),
              value: _notifyRoleChange,
              onChanged: (v) {
                setState(() => _notifyRoleChange = v);
                _updateNotificationSettings();
              },
            ),
          ],
          const Divider(height: 1),
          const SizedBox(height: 16),
          if (widget.provider == null) ...[
            const _SectionHeader(label: '보안'),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('비밀번호 변경'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPasswordChangeDialog(context),
            ),
            const Divider(height: 1),
            const SizedBox(height: 16),
          ],
          const Divider(height: 1),
          const SizedBox(height: 16),
          _SectionHeader(label: '계정'),
          ListTile(
            leading:
                const Icon(Icons.delete_outline, color: AppColors.destructive),
            title: const Text('계정 탈퇴',
                style: TextStyle(color: AppColors.destructive)),
            onTap: _handleDeleteAccount,
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    List<Map<String, dynamic>> ownerTrips;
    try {
      ownerTrips = await _api.fetchOwnerTrips();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
      return;
    }

    if (!mounted) return;

    if (ownerTrips.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('탈퇴 불가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('탈퇴 전 아래 여행을 먼저 삭제해주세요:'),
              const SizedBox(height: 8),
              ...ownerTrips.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '• ${t['title']}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('닫기'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('계정 탈퇴'),
        content: const Text(
          '탈퇴 시 현재 속한 모든 여행에서 탈퇴됩니다.\n이 작업은 되돌릴 수 없습니다. 계속하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.destructive),
            child: const Text('예, 탈퇴합니다'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _api.deleteAccount();
      await _auth.logout();
      if (!mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('계정 탈퇴에 실패했습니다. 다시 시도해주세요.')),
      );
    }
  }

  Future<void> _showPasswordChangeDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PasswordChangeDialog(api: _api),
    );
  }

  Future<void> _showNicknameDialog(BuildContext context) async {
    final controller =
        TextEditingController(text: _nickname ?? '');
    final api = ApiService();
    final auth = AuthService();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('닉네임 수정'),
        content: TextField(
          controller: controller,
          maxLength: 50,
          decoration: const InputDecoration(
            hintText: '새 닉네임을 입력하세요',
            counterText: '',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final nickname = controller.text.trim();
              if (nickname.isEmpty) return;
              try {
                await api.updateNickname(nickname);
                await auth.updateNickname(nickname);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  setState(() => _nickname = nickname);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('닉네임이 변경되었습니다.')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('닉네임 변경에 실패했습니다.')),
                  );
                }
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class _PasswordChangeDialog extends StatefulWidget {
  final ApiService api;
  const _PasswordChangeDialog({required this.api});

  @override
  State<_PasswordChangeDialog> createState() => _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends State<_PasswordChangeDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final current = _currentController.text;
    final newPw = _newController.text;
    final confirm = _confirmController.text;

    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      setState(() => _error = '모든 항목을 입력해주세요.');
      return;
    }
    if (newPw.length < 8) {
      setState(() => _error = '새 비밀번호는 8자 이상이어야 합니다.');
      return;
    }
    if (newPw != confirm) {
      setState(() => _error = '새 비밀번호가 일치하지 않습니다.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.changePassword(current, newPw);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비밀번호가 변경되었습니다.')),
        );
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      setState(() {
        if (status == 401) {
          _error = '현재 비밀번호가 올바르지 않습니다.';
        } else {
          _error = '비밀번호 변경에 실패했습니다.';
        }
        _saving = false;
      });
    } catch (_) {
      setState(() {
        _error = '비밀번호 변경에 실패했습니다.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('비밀번호 변경'),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _currentController,
            obscureText: _obscureCurrent,
            decoration: InputDecoration(
              labelText: '현재 비밀번호',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newController,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: '새 비밀번호 (8자 이상)',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: '새 비밀번호 확인',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('취소'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('변경'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSub,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
