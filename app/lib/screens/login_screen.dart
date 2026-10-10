import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' show isKakaoTalkInstalled;
import '../main.dart' show navigatorKey, pendingInviteToken, showInviteJoinDialog, registerFcmToken;
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import 'guest_community_screen.dart';
import 'main_screen.dart';
import 'onboarding_screen.dart';
import 'signup_screen.dart';

const _kakaoYellow = Color(0xFFFEE500);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _api = ApiService();
  final _auth = AuthService();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _resetEmailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _navigateAfterAuth(bool onboardingDone) async {
    if (!mounted) return;
    registerFcmToken();
    if (!onboardingDone) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } else {
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
  }

  Future<void> _socialLogin(String provider) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      String? socialToken;
      if (provider == 'google') {
        socialToken = await _auth.getGoogleIdToken();
      } else {
        bool forceAccount = false;
        if (await isKakaoTalkInstalled()) {
          final choice = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('카카오 로그인'),
              content: const Text('로그인 방식을 선택하세요.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'talk'),
                  child: const Text('카카오톡 계정으로 로그인'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'account'),
                  child: const Text('다른 계정으로 로그인'),
                ),
              ],
            ),
          );
          if (choice == null) {
            setState(() => _loading = false);
            return;
          }
          forceAccount = choice == 'account';
        }
        socialToken = await _auth.getKakaoAccessToken(forceAccount: forceAccount);
      }
      if (socialToken == null) {
        setState(() => _loading = false);
        return;
      }

      final result = await _api.oauthLogin(provider, socialToken);
      await _auth.saveToken(result.token, result.userId,
          nickname: result.nickname, profileImageUrl: result.profileImageUrl,
          onboardingDone: result.onboardingDone);
      await _navigateAfterAuth(result.onboardingDone);
    } on DioException catch (e) {
      setState(() => _errorMessage = '소셜 로그인에 실패했습니다. (${e.response?.statusCode})');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showPasswordResetDialog() async {
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PasswordResetDialog(),
    );
    if (sent == true && mounted) {
      setState(() => _resetEmailSent = true);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = await _api.login(
          _emailController.text.trim(), _passwordController.text);
      await _auth.saveToken(result.token, result.userId,
          nickname: result.nickname, profileImageUrl: result.profileImageUrl,
          onboardingDone: result.onboardingDone);
      await _navigateAfterAuth(result.onboardingDone);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      setState(() {
        _errorMessage = status == 401
            ? '이메일 또는 비밀번호가 올바르지 않습니다.'
            : '오류가 발생했습니다. 다시 시도해주세요.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: AppColors.primaryDark,
                  labelStyle: const TextStyle(color: AppColors.textSub),
                  hintStyle: const TextStyle(color: AppColors.textSub),
                  prefixIconColor: AppColors.textSub,
                  suffixIconColor: AppColors.textSub,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: Color(0xFF3A4562)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: Color(0xFF3A4562)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide:
                        const BorderSide(color: AppColors.accent, width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 32),
                    // 로고
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.location_on, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'TripMapTrace',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '여행을 지도 위에 기록하세요',
                      style: TextStyle(fontSize: 14, color: AppColors.textSub),
                    ),
                    const SizedBox(height: 36),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: '이메일',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '이메일을 입력해주세요.';
                        if (!v.contains('@')) return '올바른 이메일 형식이 아닙니다.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return '비밀번호를 입력해주세요.';
                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: AppColors.destructive, fontSize: 13),
                      ),
                    ],
                    if (_resetEmailSent) ...[
                      const SizedBox(height: 12),
                      const Text(
                        '재설정 링크를 이메일로 발송했습니다.',
                        style:
                            TextStyle(color: AppColors.accent, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('로그인',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                    // 보조 링크: 비번찾기(보조)와 회원가입(강조)을 한 줄로 묶어 위계를 부여
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _loading ? null : _showPasswordResetDialog,
                            style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 4)),
                            child: const Text(
                              '비밀번호를 잊으셨나요?',
                              style: TextStyle(
                                  color: AppColors.textSub, fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const SignupScreen()),
                                    ),
                            style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 4)),
                            child: const Text(
                              '회원가입',
                              style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Color(0xFF3A4562))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('또는',
                              style: const TextStyle(
                                  color: AppColors.textSub, fontSize: 13)),
                        ),
                        const Expanded(child: Divider(color: Color(0xFF3A4562))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 구글 로그인 버튼
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : () => _socialLogin('google'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                        icon: Image.network(
                          'https://www.google.com/favicon.ico',
                          width: 20,
                          height: 20,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.g_mobiledata, size: 20),
                        ),
                        label: const Text('Google로 계속하기',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 카카오 로그인 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : () => _socialLogin('kakao'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kakaoYellow,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.chat_bubble,
                            size: 20, color: Color(0xFF3A1D1D)),
                        label: const Text('카카오로 계속하기',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3A1D1D))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 게스트 모드는 별도 화면으로 가는 진짜 진입점이므로
                    // 흐린 텍스트가 아니라 아웃라인 버튼으로 승격해 존재감을 준다.
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const GuestCommunityScreen(),
                                  ),
                                ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF4B5568)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                        icon: const Icon(Icons.explore_outlined, size: 18),
                        label: const Text('로그인 없이 둘러보기',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 비밀번호 재설정 이메일 발송 다이얼로그
class _PasswordResetDialog extends StatefulWidget {
  const _PasswordResetDialog();

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  final _emailController = TextEditingController();
  final _api = ApiService();
  bool _sending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('비밀번호 재설정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('가입하신 이메일 주소를 입력하면\n재설정 링크를 보내드립니다.'),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '이메일',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _sending
                    ? null
                    : () async {
                        final email = _emailController.text.trim();
                        if (email.isEmpty || !email.contains('@')) return;
                        setState(() => _sending = true);
                        try {
                          await _api.requestPasswordReset(email);
                        } catch (_) {
                          // 보안상 항상 성공으로 처리
                        }
                        if (mounted) Navigator.pop(context, true);
                      },
                child: _sending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('발송'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
