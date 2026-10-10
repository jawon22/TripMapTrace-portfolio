package tripmaps.backend.auth.service;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tripmaps.backend.auth.api.dto.AuthResponse;
import tripmaps.backend.config.JwtUtils;
import tripmaps.backend.user.domain.User;
import tripmaps.backend.user.repository.UserRepository;

@Service
@Transactional
public class OAuthService {

    private final UserRepository userRepository;
    private final JwtUtils jwtUtils;
    private final GoogleTokenVerifier googleTokenVerifier;
    private final KakaoTokenVerifier kakaoTokenVerifier;

    public OAuthService(UserRepository userRepository, JwtUtils jwtUtils,
                        GoogleTokenVerifier googleTokenVerifier,
                        KakaoTokenVerifier kakaoTokenVerifier) {
        this.userRepository = userRepository;
        this.jwtUtils = jwtUtils;
        this.googleTokenVerifier = googleTokenVerifier;
        this.kakaoTokenVerifier = kakaoTokenVerifier;
    }

    public AuthResponse loginWithGoogle(String idToken) {
        OAuthUserInfo info = googleTokenVerifier.verify(idToken);
        return processOAuthLogin("google", info);
    }

    public AuthResponse loginWithKakao(String accessToken) {
        OAuthUserInfo info = kakaoTokenVerifier.verify(accessToken);
        return processOAuthLogin("kakao", info);
    }

    private AuthResponse processOAuthLogin(String provider, OAuthUserInfo info) {
        User user = userRepository.findByProviderAndProviderId(provider, info.providerId())
                .orElseGet(() -> {
                    String nickname = info.nickname() != null ? info.nickname() : info.email();
                    User newUser = User.createOAuthUser(
                            info.email(), provider, info.providerId(), nickname, info.profileImageUrl());
                    return userRepository.save(newUser);
                });

        if (info.profileImageUrl() != null && !info.profileImageUrl().equals(user.getProfileImageUrl())) {
            user.updateProfileImageUrl(info.profileImageUrl());
        }

        return new AuthResponse(
                jwtUtils.generateToken(user.getId()),
                user.getId(),
                user.getNickname(),
                user.getProfileImageUrl(),
                user.isOnboardingDone()
        );
    }
}
