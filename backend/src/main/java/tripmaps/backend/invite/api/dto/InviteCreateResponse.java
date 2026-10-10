package tripmaps.backend.invite.api.dto;

import java.time.Instant;

public record InviteCreateResponse(
    String token,
    Instant expiresAt,
    int maxUses
) {}
