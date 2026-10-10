package tripmaps.backend.invite.api.dto;

import java.time.Instant;

public record InviteStatusResponse(
        String token,
        Instant expiresAt,
        boolean isExpired
) {}
