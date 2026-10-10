package tripmaps.backend.invitation.api.dto;

public record UserSearchResponse(
        Long id,
        String nickname,
        String email,
        String profileImageUrl
) {
}
