package tripmaps.backend.auth.service;

public record OAuthUserInfo(String providerId, String email, String nickname, String profileImageUrl) {}
