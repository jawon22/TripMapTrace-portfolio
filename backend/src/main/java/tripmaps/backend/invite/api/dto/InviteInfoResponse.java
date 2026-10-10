package tripmaps.backend.invite.api.dto;

public record InviteInfoResponse(
        String tripTitle,
        int memberCount,
        String ownerNickname
) {}
