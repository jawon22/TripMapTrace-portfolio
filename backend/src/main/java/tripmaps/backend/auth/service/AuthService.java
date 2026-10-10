package tripmaps.backend.auth.service;

import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import tripmaps.backend.auth.api.dto.AuthResponse;
import tripmaps.backend.auth.api.dto.LoginRequest;
import tripmaps.backend.auth.api.dto.PasswordResetDto;
import tripmaps.backend.auth.api.dto.PasswordResetRequestDto;
import tripmaps.backend.auth.api.dto.RegisterRequest;
import tripmaps.backend.auth.domain.PasswordResetToken;
import tripmaps.backend.auth.repository.PasswordResetTokenRepository;
import tripmaps.backend.config.JwtUtils;
import tripmaps.backend.user.domain.User;
import tripmaps.backend.user.repository.UserRepository;

@Service
@Transactional
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtils jwtUtils;
    private final PasswordResetTokenRepository resetTokenRepository;
    private final EmailService emailService;

    public AuthService(UserRepository userRepository,
                       PasswordEncoder passwordEncoder,
                       JwtUtils jwtUtils,
                       PasswordResetTokenRepository resetTokenRepository,
                       EmailService emailService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtils = jwtUtils;
        this.resetTokenRepository = resetTokenRepository;
        this.emailService = emailService;
    }

    public AuthResponse register(RegisterRequest req) {
        if (userRepository.existsByEmail(req.email())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "이미 사용 중인 이메일입니다.");
        }
        User user = User.create(req.email(), passwordEncoder.encode(req.password()), req.nickname(),
                req.pushAgreed(), req.marketingAgreed());
        userRepository.save(user);
        return new AuthResponse(jwtUtils.generateToken(user.getId()), user.getId(), user.getNickname(), null, false);
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest req) {
        User user = userRepository.findByEmail(req.email())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "이메일 또는 비밀번호가 올바르지 않습니다."));

        if (!passwordEncoder.matches(req.password(), user.getPasswordHash())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "이메일 또는 비밀번호가 올바르지 않습니다.");
        }

        return new AuthResponse(jwtUtils.generateToken(user.getId()), user.getId(), user.getNickname(), null, user.isOnboardingDone());
    }

    /** 비밀번호 재설정 이메일 발송 (소셜 유저 포함 항상 "발송됨" 응답 — 계정 존재 여부 노출 방지) */
    public void requestPasswordReset(PasswordResetRequestDto req) {
        userRepository.findByEmail(req.email()).ifPresent(user -> {
            if (user.getProvider() != null) return; // 소셜 유저 무시

            PasswordResetToken resetToken = PasswordResetToken.create(user, 30);
            resetTokenRepository.save(resetToken);
            emailService.sendPasswordResetEmail(user.getEmail(), resetToken.getToken());
        });
    }

    /** 토큰 검증 후 새 비밀번호 저장 */
    public void resetPassword(PasswordResetDto req) {
        PasswordResetToken resetToken = resetTokenRepository.findByToken(req.token())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "유효하지 않은 재설정 링크입니다."));

        if (resetToken.isExpired()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "재설정 링크가 만료되었습니다.");
        }
        if (resetToken.isUsed()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "이미 사용된 재설정 링크입니다.");
        }

        User user = resetToken.getUser();
        user.updatePasswordHash(passwordEncoder.encode(req.newPassword()));
        resetToken.markUsed();
    }
}
