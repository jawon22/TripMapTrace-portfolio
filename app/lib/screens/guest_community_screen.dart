import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'community_tab.dart';

class GuestCommunityScreen extends StatelessWidget {
  const GuestCommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const CommunityTab(isGuest: true),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: '커뮤니티',
          ),
        ],
        onTap: (_) {},
      ),
    );
  }
}
