package tripmaps.backend.auth.api;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import tripmaps.backend.auth.api.dto.AuthResponse;
import tripmaps.backend.auth.api.dto.LoginRequest;
import tripmaps.backend.auth.api.dto.PasswordResetDto;
import tripmaps.backend.auth.api.dto.PasswordResetRequestDto;
import tripmaps.backend.auth.api.dto.RegisterRequest;
import tripmaps.backend.auth.service.AuthService;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register")
    public AuthResponse register(@Valid @RequestBody RegisterRequest req) {
        return authService.register(req);
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest req) {
        return authService.login(req);
    }

    @PostMapping("/password/reset-request")
    public ResponseEntity<Void> requestPasswordReset(@Valid @RequestBody PasswordResetRequestDto req) {
        authService.requestPasswordReset(req);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/password/reset")
    public ResponseEntity<Void> resetPassword(@Valid @RequestBody PasswordResetDto req) {
        authService.resetPassword(req);
        return ResponseEntity.ok().build();
    }
}
