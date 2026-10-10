package tripmaps.backend.auth.service;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;

@Component
public class GoogleTokenVerifier {

    private final RestClient restClient;

    public GoogleTokenVerifier() {
        this.restClient = RestClient.create();
    }

    @SuppressWarnings("unchecked")
    public OAuthUserInfo verify(String idToken) {
        try {
            Map<String, Object> claims = restClient.get()
                    .uri("https://oauth2.googleapis.com/tokeninfo?id_token=" + idToken)
                    .retrieve()
                    .body(Map.class);

            if (claims == null || claims.get("sub") == null) {
                throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "유효하지 않은 Google 토큰입니다.");
            }

            String providerId = (String) claims.get("sub");
            String email = (String) claims.get("email");
            String name = (String) claims.get("name");
            String picture = (String) claims.get("picture");

            return new OAuthUserInfo(providerId, email, name, picture);
        } catch (ResponseStatusException e) {
            throw e;
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Google 토큰 검증에 실패했습니다.");
        }
    }
}
