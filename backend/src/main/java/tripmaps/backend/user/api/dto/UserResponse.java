package tripmaps.backend.user.api.dto;

public record UserResponse(Long id, String email, String nickname, String profileImageUrl, String provider) {}
