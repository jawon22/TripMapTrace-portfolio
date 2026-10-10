package tripmaps.backend.invitation.api.dto;

public record ReceivedInvitationResponse(
        Long id,
        Long tripId,
        String tripTitle,
        String inviterNickname,
        int memberCount
) {
}
