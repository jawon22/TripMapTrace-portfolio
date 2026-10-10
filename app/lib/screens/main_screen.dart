import 'package:flutter/material.dart';
import '../main.dart' show notificationRefreshNotifier;
import '../services/api_service.dart';
import 'community_tab.dart';
import 'home_tab.dart';
import 'global_map_tab.dart';
import 'notification_screen.dart';
import 'profile_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _api = ApiService();
  int _currentIndex = 0;
  int _mapTapCount = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    notificationRefreshNotifier.addListener(_loadUnreadCount);
  }

  @override
  void dispose() {
    notificationRefreshNotifier.removeListener(_loadUnreadCount);
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _api.fetchUnreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotificationScreen(api: _api)),
    );
    _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeTab(
            isActive: _currentIndex == 0,
            unreadCount: _unreadCount,
            onBellTap: _openNotifications,
          ),
          CommunityTab(
            unreadCount: _unreadCount,
            onBellTap: _openNotifications,
          ),
          GlobalMapTab(isActive: _currentIndex == 2, tapCount: _mapTapCount),
          ProfileTab(
            onNavigateToHome: () => setState(() => _currentIndex = 0),
            isActive: _currentIndex == 3,
            unreadCount: _unreadCount,
            onBellTap: _openNotifications,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 2) _mapTapCount++;
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: '커뮤니티',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: '지도',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '프로필',
          ),
        ],
      ),
    );
  }
}
