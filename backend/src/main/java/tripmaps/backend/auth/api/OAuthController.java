package tripmaps.backend.auth.api;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import tripmaps.backend.auth.api.dto.AuthResponse;
import tripmaps.backend.auth.api.dto.OAuthRequest;
import tripmaps.backend.auth.service.OAuthService;

@RestController
@RequestMapping("/api/v1/auth/oauth")
public class OAuthController {

    private final OAuthService oAuthService;

    public OAuthController(OAuthService oAuthService) {
        this.oAuthService = oAuthService;
    }

    @PostMapping("/google")
    public AuthResponse googleLogin(@RequestBody OAuthRequest req) {
        return oAuthService.loginWithGoogle(req.token());
    }

    @PostMapping("/kakao")
    public AuthResponse kakaoLogin(@RequestBody OAuthRequest req) {
        return oAuthService.loginWithKakao(req.token());
    }
}
