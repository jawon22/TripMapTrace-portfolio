import 'package:flutter/material.dart';
import '../theme/app_radius.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart' show Share;
import '../config/app_links.dart';
import '../services/api_service.dart';
import 'app_snackbar.dart';

class InviteBottomSheet extends StatefulWidget {
  final ApiService api;
  final int tripId;

  const InviteBottomSheet({
    super.key,
    required this.api,
    required this.tripId,
  });

  @override
  State<InviteBottomSheet> createState() => _InviteBottomSheetState();
}

class _InviteBottomSheetState extends State<InviteBottomSheet> {
  String? _token;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ensureToken();
  }

  /// 시트 진입 시 유효한 초대 토큰을 확보한다.
  /// 기존 토큰이 없거나 만료됐으면 조용히 재발급하여, 만료/재발급 UI를
  /// 노출하지 않고도 사용자가 항상 바로 공유할 수 있게 한다.
  Future<void> _ensureToken() async {
    setState(() => _loading = true);
    try {
      final status = await widget.api.fetchInviteStatus(widget.tripId);
      final token = status['token'] as String?;
      final isExpired = status['isExpired'] as bool? ?? true;
      if (token == null || isExpired) {
        await _issueToken();
      } else {
        setState(() => _token = token);
      }
    } catch (_) {
      // status 조회 실패 시에도 새 토큰 발급을 시도한다.
      await _issueToken();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 새 초대 토큰을 발급한다.
  Future<void> _issueToken() async {
    try {
      final result = await widget.api.generateInvite(widget.tripId);
      if (mounted) setState(() => _token = result['token'] as String?);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '초대 코드 발급 실패: $e');
    }
  }

  /// 초대 코드를 클립보드에 복사한다.
  Future<void> _copyCode() async {
    if (_token == null) return;
    await Clipboard.setData(ClipboardData(text: _token!));
    if (mounted) showSuccessSnackBar(context, '초대 코드를 복사했습니다');
  }

  /// 초대 링크와 코드를 담아 공유한다.
  /// 링크는 App Links(https)라 앱이 설치돼 있으면 탭 시 바로 열리고,
  /// 없으면 안내 페이지로 연결된다. 코드는 수동 참여용 보조 수단.
  void _share() {
    if (_token == null) return;
    final url = buildInviteUrl(_token!);
    final message = '함께 여행을 기록해요! ✈️\n'
        '\n'
        '아래 링크를 누르면 앱에서 바로 열려요:\n'
        '$url\n'
        '\n'
        '앱이 없다면 홈에서 "초대 코드로 참여"에 아래 코드를 입력하세요.\n'
        '초대 코드: $_token';
    Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '여행에 초대하기',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const SizedBox(
                height: 200, child: Center(child: CircularProgressIndicator()))
          else if (_token == null)
            _buildErrorState()
          else
            _buildActiveState(),
        ],
      ),
    );
  }

  Widget _buildActiveState() {
    final deepLink = buildInviteUrl(_token!);

    return Column(
      children: [
        // QR 코드 (대면 스캔용)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: QrImageView(
            data: deepLink,
            version: QrVersions.auto,
            size: 200,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'QR을 스캔하거나 초대 코드를 공유하세요',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('공유'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copyCode,
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('코드 복사'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        const SizedBox(height: 32),
        Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(
          '초대 코드를 준비하지 못했습니다',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _ensureToken,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
