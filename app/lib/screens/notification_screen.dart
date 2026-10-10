import 'package:flutter/material.dart';
import '../models/notification_item.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'trip_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  final ApiService api;
  const NotificationScreen({super.key, required this.api});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await widget.api.fetchNotifications();
      final items = raw
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() => _items = items);
      await widget.api.markAllNotificationsRead();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteItem(NotificationItem item) async {
    final idx = _items.indexOf(item);
    setState(() => _items.removeAt(idx));
    try {
      await widget.api.deleteNotification(item.id);
    } catch (_) {
      if (mounted) setState(() => _items.insert(idx, item));
    }
  }

  Future<void> _onTap(NotificationItem item) async {
    final tripId = item.targetTripId;
    if (tripId == null) return;

    try {
      final trips = await widget.api.fetchTrips();
      final trip = trips.cast<Trip?>().firstWhere(
            (t) => t?.id == tripId,
            orElse: () => null,
          );
      if (trip == null || !mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('해당 여행에 접근할 수 없습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Text('알림이 없어요',
                      style: TextStyle(color: AppColors.textSub, fontSize: 14)),
                )
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, index) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) => _buildItem(_items[i]),
                ),
    );
  }

  Widget _buildItem(NotificationItem item) {
    final timeAgo = _formatTimeAgo(item.createdAt);
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _deleteItem(item),
      child: InkWell(
        onTap: item.targetTripId != null ? () => _onTap(item) : null,
        child: Container(
          color: item.isRead ? null : AppColors.primary.withValues(alpha: 0.04),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.iconColor(context).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 18, color: item.iconColor(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.body,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            item.isRead ? FontWeight.normal : FontWeight.w600,
                        color: AppColors.textOnLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSub),
                    ),
                  ],
                ),
              ),
              if (!item.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4, left: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }
}
