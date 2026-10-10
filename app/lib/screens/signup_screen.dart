import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../main.dart' show navigatorKey, pendingInviteToken, showInviteJoinDialog, registerFcmToken;
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import 'main_screen.dart';
import 'onboarding_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _TermsItem {
  final String title;
  final bool required;
  final String content;
  bool agreed;

  _TermsItem({
    required this.title,
    required this.required,
    required this.content,
    this.agreed = false,
  });
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _api = ApiService();
  final _auth = AuthService();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final List<_TermsItem> _terms = [
    _TermsItem(
      title: '[필수] 이용약관 동의',
      required: true,
      content: '본 약관은 TripMapTrace 서비스 이용에 관한 기본 사항을 규정합니다.\n\n'
          '• 서비스 이용 목적 외 사용 금지\n'
          '• 타인의 개인정보 침해 금지\n'
          '• 서비스 내 콘텐츠 무단 복제 및 배포 금지\n'
          '• 계정은 본인만 사용 가능하며 타인에게 양도 불가',
    ),
    _TermsItem(
      title: '[필수] 개인정보 처리방침 동의',
      required: true,
      content: '수집 항목: 이메일, 닉네임, 소셜 계정 식별자\n\n'
          '수집 목적: 회원 식별 및 서비스 제공\n\n'
          '보유 기간: 회원 탈퇴 시까지\n\n'
          '제3자 제공: 없음 (소셜 로그인 제공사 제외)',
    ),
    _TermsItem(
      title: '[필수] 위치정보 수집·이용 동의',
      required: true,
      content: '수집 항목: 업로드한 사진의 EXIF GPS 좌표\n\n'
          '수집 목적: 지도에 사진 위치 표시\n\n'
          '보유 기간: 해당 미디어 삭제 시까지\n\n'
          '위치정보는 서버에 저장되며 해당 여행 멤버에게 공개됩니다.',
    ),
    _TermsItem(
      title: '[필수] 미디어 서버 저장 동의',
      required: true,
      content: '업로드한 사진 및 영상은 클라우드 서버에 저장됩니다.\n\n'
          '저장 목적: 미디어 공유 및 타임라인/지도 표시\n\n'
          '접근 권한: 해당 여행 멤버\n\n'
          '미디어는 여행 삭제 또는 개별 삭제 요청 시 제거됩니다.',
    ),
    _TermsItem(
      title: '[선택] 푸시 알림 수신 동의',
      required: false,
      content: '업로드, 초대, 댓글 등 이벤트 발생 시 푸시 알림을 수신합니다.\n\n'
          '언제든지 설정에서 알림을 끌 수 있습니다.',
    ),
    _TermsItem(
      title: '[선택] 마케팅 정보 수신 동의',
      required: false,
      content: '이벤트, 업데이트, 신규 기능 안내 등 마케팅 정보를 수신합니다.\n\n'
          '언제든지 설정에서 수신을 거부할 수 있습니다.',
    ),
  ];

  bool get _allRequired => _terms.where((t) => t.required).every((t) => t.agreed);
  bool get _allAgreed => _terms.every((t) => t.agreed);

  void _toggleAll(bool value) {
    setState(() {
      for (final t in _terms) {
        t.agreed = value;
      }
    });
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_allRequired) {
      setState(() => _errorMessage = '필수 약관에 모두 동의해주세요.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = await _api.register(
        _emailController.text.trim(),
        _passwordController.text,
        _nicknameController.text.trim(),
        pushAgreed: _terms[4].agreed,
        marketingAgreed: _terms[5].agreed,
      );
      await _auth.saveToken(result.token, result.userId,
          nickname: result.nickname, profileImageUrl: result.profileImageUrl,
          onboardingDone: result.onboardingDone);
      await _navigateAfterAuth(result.onboardingDone);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      setState(() {
        _errorMessage = status == 409
            ? '이미 사용 중인 이메일입니다.'
            : '오류가 발생했습니다. 다시 시도해주세요.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('회원가입'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                  borderSide: const BorderSide(color: AppColors.accent, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 입력 필드 ──────────────────────────────
                  TextFormField(
                    controller: _nicknameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: '닉네임',
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return '닉네임을 입력해주세요.';
                      if (v.trim().length > 50) return '닉네임은 50자 이하이어야 합니다.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
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
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return '비밀번호를 입력해주세요.';
                      if (v.length < 6) return '비밀번호는 6자 이상이어야 합니다.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  // ── 약관 동의 ──────────────────────────────
                  const Text(
                    '약관 동의',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  // 전체 동의
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: const Color(0xFF3A4562)),
                    ),
                    child: CheckboxListTile(
                      value: _allAgreed,
                      onChanged: (v) => _toggleAll(v ?? false),
                      title: const Text(
                        '전체 동의',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      activeColor: AppColors.accent,
                      checkColor: Colors.white,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 개별 약관 항목 (ExpansionTile)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: const Color(0xFF3A4562)),
                    ),
                    child: Column(
                      children: _terms.asMap().entries.map((entry) {
                        final i = entry.key;
                        final term = entry.value;
                        return Column(
                          children: [
                            Theme(
                              data: Theme.of(context).copyWith(
                                dividerColor: Colors.transparent,
                              ),
                              child: ExpansionTile(
                                leading: Checkbox(
                                  value: term.agreed,
                                  onChanged: (v) =>
                                      setState(() => term.agreed = v ?? false),
                                  activeColor: AppColors.accent,
                                  checkColor: Colors.white,
                                  side: const BorderSide(color: AppColors.textSub),
                                ),
                                title: Text(
                                  term.title,
                                  style: TextStyle(
                                    color: term.required
                                        ? Colors.white
                                        : AppColors.textSub,
                                    fontSize: 13,
                                  ),
                                ),
                                iconColor: AppColors.textSub,
                                collapsedIconColor: AppColors.textSub,
                                tilePadding:
                                    const EdgeInsets.only(left: 0, right: 12),
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    child: Text(
                                      term.content,
                                      style: const TextStyle(
                                        color: AppColors.textSub,
                                        fontSize: 12,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (i < _terms.length - 1)
                              const Divider(
                                height: 1,
                                color: Color(0xFF3A4562),
                                indent: 16,
                                endIndent: 16,
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: AppColors.destructive, fontSize: 13),
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
                          : const Text('가입하기',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text(
                        '이미 계정이 있으신가요? 로그인',
                        style: TextStyle(color: AppColors.textSub, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
