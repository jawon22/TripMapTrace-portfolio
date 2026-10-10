package tripmaps.backend.auth.api.dto;

public record AuthResponse(String token, Long userId, String nickname, String profileImageUrl, boolean onboardingDone) {}
