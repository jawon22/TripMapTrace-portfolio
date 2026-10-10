import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../widgets/app_snackbar.dart';

class InviteJoinDialog extends StatefulWidget {
  final String token;
  final String tripTitle;
  final int memberCount;
  final String ownerNickname;
  final ApiService api;

  const InviteJoinDialog({
    super.key,
    required this.token,
    required this.tripTitle,
    required this.memberCount,
    required this.ownerNickname,
    required this.api,
  });

  @override
  State<InviteJoinDialog> createState() => _InviteJoinDialogState();
}

class _InviteJoinDialogState extends State<InviteJoinDialog> {
  bool _loading = false;

  Future<void> _join() async {
    setState(() => _loading = true);
    try {
      await widget.api.joinByToken(widget.token);
      if (!mounted) return;
      tripListRefreshNotifier.value++;
      Navigator.pop(context);
      showSuccessSnackBar(context, '\'${widget.tripTitle}\' 여행에 참여했습니다!');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      String msg = '참여에 실패했습니다. 다시 시도해주세요.';
      if (e is DioException) {
        final body = e.response?.data?.toString() ?? '';
        if (body.contains('이미 참여')) msg = '이미 참여 중인 여행입니다.';
      }
      showErrorSnackBar(context, msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('여행 초대'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.tripTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.ownerNickname}님이 초대했습니다',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '현재 멤버 ${widget.memberCount}명',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const Text('이 여행에 참여하시겠습니까?', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _loading ? null : _join,
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('참여하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
