import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/user_search_result.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'app_snackbar.dart';

/// 닉네임/이메일로 사용자를 검색해 여행에 직접 초대하는 바텀시트.
class InviteSearchSheet extends StatefulWidget {
  final ApiService api;
  final int tripId;

  const InviteSearchSheet({
    super.key,
    required this.api,
    required this.tripId,
  });

  @override
  State<InviteSearchSheet> createState() => _InviteSearchSheetState();
}

class _InviteSearchSheetState extends State<InviteSearchSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<UserSearchResult> _results = [];
  bool _loading = false;
  bool _searched = false;
  final Set<int> _invitedIds = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final results = await widget.api.searchUsers(q);
      if (mounted) {
        setState(() {
          _results = results;
          _searched = true;
        });
      }
    } catch (_) {
      if (mounted) showErrorSnackBar(context, '검색에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite(UserSearchResult user) async {
    try {
      await widget.api.sendInvitation(widget.tripId, user.id);
      if (mounted) {
        setState(() => _invitedIds.add(user.id));
        showSuccessSnackBar(context, '${user.displayName}님을 초대했습니다.');
      }
    } catch (e) {
      String msg = '초대에 실패했습니다.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          msg = data['message'] as String;
        }
      }
      if (mounted) showErrorSnackBar(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            '사용자 초대',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: '닉네임 또는 이메일 입력',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_searched && !_loading && _results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('검색 결과가 없습니다.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    if (_results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('초대할 사용자를 검색하세요.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final user = _results[i];
        final invited = _invitedIds.contains(user.id);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: AppColors.accent.withValues(alpha: 0.15),
            backgroundImage: user.profileImageUrl != null
                ? NetworkImage(user.profileImageUrl!)
                : null,
            child: user.profileImageUrl == null
                ? Text(
                    user.displayName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: AppColors.accent),
                  )
                : null,
          ),
          title: Text(user.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: user.email != null
              ? Text(user.email!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey))
              : null,
          trailing: invited
              ? const Text('초대됨',
                  style: TextStyle(color: Colors.grey, fontSize: 13))
              : FilledButton(
                  onPressed: () => _invite(user),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('초대'),
                ),
        );
      },
    );
  }
}
