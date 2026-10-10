package tripmaps.backend.invite.api.dto;

public record InviteJoinResponse(
    Long tripId,
    Long userId,
    String role
) {}
