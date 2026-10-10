import 'package:flutter/material.dart';
import '../main.dart' show pendingInviteToken, navigatorKey, showInviteJoinDialog, registerFcmToken;
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import 'main_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingPage {
  final IconData icon;
  final List<_Badge> badges;
  final Color color;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.badges,
    required this.color,
    required this.title,
    required this.description,
  });
}

class _Badge {
  final IconData icon;
  final double top;
  final double? left;
  final double? right;

  const _Badge({required this.icon, required this.top, this.left, this.right});
}

const _pages = [
  _OnboardingPage(
    icon: Icons.add_location_alt,
    color: Color(0xFFF59E0B),
    title: '여행을 만들어요',
    description: '새 여행을 만들고\n초대 링크로 동행자를 초대하세요.',
    badges: [
      _Badge(icon: Icons.luggage, top: 28, left: 32),
      _Badge(icon: Icons.person_add, top: 28, right: 32),
      _Badge(icon: Icons.link, top: 168, left: 48),
      _Badge(icon: Icons.group, top: 168, right: 48),
    ],
  ),
  _OnboardingPage(
    icon: Icons.photo_camera,
    color: Color(0xFF3B82F6),
    title: '사진을 올려요',
    description: 'GPS가 담긴 사진을 올리면\n경로가 자동으로 기록돼요.',
    badges: [
      _Badge(icon: Icons.gps_fixed, top: 28, left: 32),
      _Badge(icon: Icons.image, top: 28, right: 32),
      _Badge(icon: Icons.upload, top: 168, left: 48),
      _Badge(icon: Icons.route, top: 168, right: 48),
    ],
  ),
  _OnboardingPage(
    icon: Icons.map,
    color: Color(0xFF10B981),
    title: '지도와 타임라인으로 돌아봐요',
    description: '찍은 위치는 지도에,\n시간순으론 타임라인에서 확인해요.',
    badges: [
      _Badge(icon: Icons.location_on, top: 28, left: 32),
      _Badge(icon: Icons.timeline, top: 28, right: 32),
      _Badge(icon: Icons.photo_album, top: 168, left: 48),
      _Badge(icon: Icons.pin_drop, top: 168, right: 48),
    ],
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  final _api = ApiService();
  final _auth = AuthService();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    try {
      await _api.completeOnboarding();
      await _auth.setOnboardingDone();
    } catch (_) {}
    if (!mounted) return;
    registerFcmToken();
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
    final token = pendingInviteToken;
    if (token != null) {
      pendingInviteToken = null;
      final ctx = navigatorKey.currentContext;
      if (ctx != null) await showInviteJoinDialog(ctx, token);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // 건너뛰기
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text(
                  '건너뛰기',
                  style: TextStyle(color: AppColors.textSub, fontSize: 14),
                ),
              ),
            ),
            // 슬라이드
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _PageContent(page: _pages[i]),
              ),
            ),
            // 인디케이터
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? AppColors.accent
                        : const Color(0xFF3A4562),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLast
                      ? _finish
                      : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: Text(
                    isLast ? '시작하기' : '다음',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  final _OnboardingPage page;

  const _PageContent({required this.page});

  // 앱 완성 후 이 메서드를 실제 스크린샷 Image.asset() 또는 Lottie 위젯으로 교체
  Widget _buildVisual() {
    return SizedBox(
      width: 280,
      height: 240,
      child: Stack(
        children: [
          // 카드 배경
          Container(
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: page.color.withValues(alpha: 0.25), width: 1.5),
            ),
          ),
          // 배경 큰 원
          Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: page.color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // 메인 아이콘
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: page.color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(page.icon, size: 46, color: page.color),
            ),
          ),
          // 보조 아이콘 배지
          ...page.badges.map(
            (b) => Positioned(
              top: b.top,
              left: b.left,
              right: b.right,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: page.color.withValues(alpha: 0.3)),
                ),
                child: Icon(b.icon, size: 20, color: page.color.withValues(alpha: 0.8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildVisual(),
          const SizedBox(height: 40),
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Text(
            page.description,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSub,
              height: 1.7,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
