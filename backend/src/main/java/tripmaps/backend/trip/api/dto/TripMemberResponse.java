package tripmaps.backend.trip.api.dto;

import java.time.Instant;

public record TripMemberResponse(
    Long memberId,
    Long userId,
    String email,
    String nickname,
    String profileImageUrl,
    String role,
    Instant joinedAt
) {}
