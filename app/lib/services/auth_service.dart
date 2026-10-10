import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

class AuthService {
  static const _tokenKey = 'jwt_token';
  static const _userIdKey = 'user_id';
  static const _nicknameKey = 'nickname';
  static const _profileImageUrlKey = 'profile_image_url';
  static const _onboardingDoneKey = 'onboarding_done';

  final _storage = const FlutterSecureStorage();
  final _googleSignIn = GoogleSignIn(
    serverClientId: '673042156859-medu5riif5cvatht17it6g6kb97je257.apps.googleusercontent.com',
  );

  Future<void> saveToken(String token, int userId,
      {String? nickname, String? profileImageUrl, bool onboardingDone = false}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId.toString());
    await _storage.write(key: _onboardingDoneKey, value: onboardingDone.toString());
    if (nickname != null) {
      await _storage.write(key: _nicknameKey, value: nickname);
    }
    if (profileImageUrl != null) {
      await _storage.write(key: _profileImageUrlKey, value: profileImageUrl);
    }
  }

  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<String?> getNickname() async {
    return _storage.read(key: _nicknameKey);
  }

  Future<int?> getUserId() async {
    final v = await _storage.read(key: _userIdKey);
    return v != null ? int.tryParse(v) : null;
  }

  Future<String?> getProfileImageUrl() async {
    return _storage.read(key: _profileImageUrlKey);
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _nicknameKey);
    await _storage.delete(key: _profileImageUrlKey);
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await UserApi.instance.logout();
    } catch (_) {}
  }

  Future<void> updateNickname(String nickname) async {
    await _storage.write(key: _nicknameKey, value: nickname);
  }

  Future<void> updateProfileImageUrl(String? url) async {
    if (url != null) {
      await _storage.write(key: _profileImageUrlKey, value: url);
    } else {
      await _storage.delete(key: _profileImageUrlKey);
    }
  }

  Future<bool> isLoggedIn() async => (await getToken()) != null;

  Future<bool> isOnboardingDone() async {
    final v = await _storage.read(key: _onboardingDoneKey);
    return v == 'true';
  }

  Future<void> setOnboardingDone() async {
    await _storage.write(key: _onboardingDoneKey, value: 'true');
  }

  /// Google ID Token 반환. 로그인 취소 시 null.
  /// signOut() 후 signIn() → 항상 계정 선택창 표시
  Future<String?> getGoogleIdToken() async {
    await _googleSignIn.signOut();
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.idToken;
  }

  /// 카카오 Access Token 반환. 로그인 취소/실패 시 null.
  /// forceAccount=true 시 웹뷰로 다른 계정 선택 가능
  Future<String?> getKakaoAccessToken({bool forceAccount = false}) async {
    try {
      await UserApi.instance.logout();
    } catch (_) {}
    try {
      final useAccount = forceAccount || !await isKakaoTalkInstalled();
      final token = useAccount
          ? await UserApi.instance.loginWithKakaoAccount()
          : await UserApi.instance.loginWithKakaoTalk();
      return token.accessToken;
    } catch (_) {
      return null;
    }
  }
}
