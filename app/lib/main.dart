import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'config/app_links.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/reset_password_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'widgets/invite_join_dialog.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// 로그인 전에 수신된 초대 토큰을 보관. 로그인 후 자동 참여에 사용.
String? pendingInviteToken;

/// 여행 참여 성공 시 HomeTab 목록 새로고침 트리거.
final tripListRefreshNotifier = ValueNotifier<int>(0);

/// 포그라운드 FCM 수신 시 MainScreen 벨 아이콘 뱃지 갱신 트리거.
final notificationRefreshNotifier = ValueNotifier<int>(0);

/// 백그라운드/종료 상태 FCM 핸들러 — top-level 함수여야 함
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // OS가 알림 트레이에 자동 표시하므로 별도 처리 불필요
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  KakaoSdk.init(nativeAppKey: '3948018e1cbe58bc99e4ba42a1d2562d');

  // FCM 백그라운드 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final auth = AuthService();
  final isLoggedIn = await auth.isLoggedIn();
  final onboardingDone = await auth.isOnboardingDone();

  // 로그인 상태이면 FCM 토큰 등록
  if (isLoggedIn) {
    registerFcmToken();
  }

  // Cold start: 앱이 딥링크로 최초 실행됐을 때 토큰 추출
  final appLinks = AppLinks();
  final initialUri = await appLinks.getInitialLink();
  if (initialUri != null) {
    _handleIncomingLink(initialUri, isLoggedIn);
  }

  runApp(MyApp(isLoggedIn: isLoggedIn, onboardingDone: onboardingDone));

  // Warm start: 앱이 백그라운드/포그라운드에서 링크 수신
  appLinks.uriLinkStream.listen((uri) async {
    final loggedIn = await AuthService().isLoggedIn();
    _handleIncomingLink(uri, loggedIn);
  });
}

/// FCM 토큰 획득 후 서버에 등록
Future<void> registerFcmToken() async {
  try {
    final messaging = FirebaseMessaging.instance;

    // Android 13+ 알림 권한 요청
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    if (token != null) {
      await ApiService().updateFcmToken(token);
    }

    // 토큰 갱신 시 서버 업데이트
    messaging.onTokenRefresh.listen((newToken) async {
      try {
        await ApiService().updateFcmToken(newToken);
      } catch (_) {}
    });
  } catch (_) {}
}

/// 포그라운드 FCM 알림 핸들러 설정 — MyApp initState에서 호출
void setupForegroundFcmHandler() {
  FirebaseMessaging.onMessage.listen((message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    if (body.isEmpty) return;

    // 인앱 배너 표시
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(body),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    // MainScreen 벨 아이콘 뱃지 갱신 트리거
    notificationRefreshNotifier.value++;
  });
}

void _handleIncomingLink(Uri uri, bool isLoggedIn) {
  String? inviteToken;
  String? resetToken;

  if (uri.scheme == 'tripmaptrace') {
    // 커스텀 스킴: tripmaptrace://invite/{token} , tripmaptrace://reset-password?token=...
    if (uri.host == 'invite') {
      inviteToken = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    } else if (uri.host == 'reset-password') {
      resetToken = uri.queryParameters['token'];
    }
  } else if (uri.scheme == 'https' && uri.host == kInviteLinkHost) {
    // App Links: https://{host}/invite/{token} , https://{host}/reset-password?token=...
    final segs = uri.pathSegments;
    if (segs.length >= 2 && segs.first == 'invite') {
      inviteToken = segs[1];
    } else if (segs.isNotEmpty && segs.first == 'reset-password') {
      resetToken = uri.queryParameters['token'];
    }
  } else {
    return;
  }

  if (inviteToken != null && inviteToken.isNotEmpty) {
    final token = inviteToken;
    if (isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = navigatorKey.currentContext;
        if (context != null) showInviteJoinDialog(context, token);
      });
    } else {
      pendingInviteToken = token;
    }
  }

  if (resetToken != null && resetToken.isNotEmpty) {
    final token = resetToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(resetToken: token),
        ),
      );
    });
  }
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  final bool onboardingDone;

  const MyApp({super.key, required this.isLoggedIn, required this.onboardingDone});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    setupForegroundFcmHandler();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'TripMapTrace',
      theme: AppTheme.light(),
      home: widget.isLoggedIn
          ? (widget.onboardingDone ? const MainScreen() : const OnboardingScreen())
          : const LoginScreen(),
    );
  }
}

/// 초대 참여 다이얼로그 — 딥링크 수신 또는 로그인 후 pendingInviteToken 처리 시 호출
Future<void> showInviteJoinDialog(BuildContext context, String token) async {
  final api = ApiService();
  try {
    final info = await api.fetchInviteInfo(token);
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => InviteJoinDialog(
        token: token,
        tripTitle: info['tripTitle'] as String,
        memberCount: info['memberCount'] as int,
        ownerNickname: info['ownerNickname'] as String,
        api: api,
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('초대 링크 오류'),
        content: const Text('유효하지 않거나 만료된 초대 링크입니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
