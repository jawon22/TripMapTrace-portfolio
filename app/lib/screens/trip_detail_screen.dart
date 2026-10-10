import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../models/trip_stats.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_snackbar.dart';
import 'member_manage_screen.dart';
import 'upload_tab.dart';
import 'timeline_tab.dart';
import 'map_tab.dart';

class TripDetailScreen extends StatefulWidget {
  final Trip trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late Trip _trip;
  late final ApiService _api;
  TripStats? _stats;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _api = ApiService();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final stats = await _api.fetchTripStats(_trip.id);
      if (mounted) setState(() => _stats = stats);
    } catch (_) {}
  }

  Future<void> _openMemberManage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberManageScreen(
          api: _api,
          tripId: _trip.id,
          isOwner: _trip.isOwner,
        ),
      ),
    );
  }

  String _tripSubtitle() {
    final parts = <String>[];
    if (_trip.startDate != null) {
      final d = _trip.startDate!;
      parts.add('${d.month}/${d.day}');
      if (_trip.endDate != null) {
        final e = _trip.endDate!;
        parts.add('~ ${e.month}/${e.day}');
      }
    }
    if (_trip.memberCount > 0) {
      parts.add('멤버 ${_trip.memberCount}명');
    }
    return parts.join(' · ');
  }

  String _fmtDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  Future<void> _showEditDialog() async {
    final controller = TextEditingController(text: _trip.title);
    DateTime? startDate = _trip.startDate;
    DateTime? endDate = _trip.endDate;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('여행 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: '여행 이름'),
                autofocus: true,
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
      final updated = await _api.updateTrip(_trip.id, title,
          startDate: startDate, endDate: endDate);
      setState(() => _trip = updated);
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
              date != null ? _fmtDate(date) : '날짜 선택',
              style: TextStyle(
                fontSize: 13,
                color: date != null
                    ? AppColors.textOnLight
                    : AppColors.textSub,
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

  @override
  Widget build(BuildContext context) {
    final isViewer = _trip.myRole == 'VIEWER';
    final subtitle = _tripSubtitle();

    final tabs = [
      const Tab(icon: Icon(Icons.view_list), text: '타임라인'),
      const Tab(icon: Icon(Icons.map_outlined), text: '지도'),
      if (!isViewer)
        const Tab(icon: Icon(Icons.cloud_upload_outlined), text: '업로드'),
    ];

    final tabViews = [
      TimelineTab(api: _api, tripId: _trip.id, myRole: _trip.myRole),
      MapTab(api: _api, tripId: _trip.id, myRole: _trip.myRole),
      if (!isViewer) UploadTab(api: _api, tripId: _trip.id, onUploadComplete: _fetchStats),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(

          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnDark,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _trip.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textSub, fontSize: 12),
                ),
            ],
          ),
          actions: [
            if (_trip.isOwner)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: '여행 설정',
                onPressed: _showEditDialog,
              ),
            IconButton(
              icon: const Icon(Icons.group_outlined),
              tooltip: '멤버 관리',
              onPressed: _openMemberManage,
            ),
          ],
          bottom: TabBar(
            tabs: tabs,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textSub,
            indicatorColor: AppColors.accent,
          ),
        ),
        body: Column(
          children: [
            if (_stats != null) _buildStatsCard(_stats!),
            Expanded(child: TabBarView(children: tabViews)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(TripStats s) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _statItem(Icons.calendar_today_outlined, '${s.dayCount}일', '촬영일'),
          _statDivider(),
          _statItem(Icons.place_outlined, '${s.locationCount}곳', '지역'),
          _statDivider(),
          _statItem(Icons.photo_outlined, '${s.photoCount}장', '사진'),
          _statDivider(),
          _statItem(Icons.videocam_outlined, '${s.videoCount}개', '영상'),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: AppColors.accent),
              const SizedBox(width: 3),
              Text(value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 1),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.textSub)),
        ],
      ),
    );
  }

  Widget _statDivider() =>
      Container(width: 1, height: 28, color: Colors.grey.shade200);
}
