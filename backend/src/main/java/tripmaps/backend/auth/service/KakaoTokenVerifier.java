package tripmaps.backend.auth.service;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;

@Component
public class KakaoTokenVerifier {

    private final RestClient restClient;

    public KakaoTokenVerifier() {
        this.restClient = RestClient.create();
    }

    @SuppressWarnings("unchecked")
    public OAuthUserInfo verify(String accessToken) {
        try {
            Map<String, Object> response = restClient.get()
                    .uri("https://kapi.kakao.com/v2/user/me")
                    .header("Authorization", "Bearer " + accessToken)
                    .retrieve()
                    .body(Map.class);

            if (response == null || response.get("id") == null) {
                throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "유효하지 않은 카카오 토큰입니다.");
            }

            String providerId = String.valueOf(response.get("id"));

            Map<String, Object> kakaoAccount = (Map<String, Object>) response.get("kakao_account");
            String email = null;
            String nickname = null;
            String profileImageUrl = null;

            if (kakaoAccount != null) {
                email = (String) kakaoAccount.get("email");
                Map<String, Object> profile = (Map<String, Object>) kakaoAccount.get("profile");
                if (profile != null) {
                    nickname = (String) profile.get("nickname");
                    profileImageUrl = (String) profile.get("profile_image_url");
                }
            }

            return new OAuthUserInfo(providerId, email, nickname, profileImageUrl);
        } catch (ResponseStatusException e) {
            throw e;
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "카카오 토큰 검증에 실패했습니다.");
        }
    }
}
