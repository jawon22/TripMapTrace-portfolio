package tripmaps.backend.community.api.dto;

import java.time.Instant;

public record CommunityCommentResponse(
        Long id,
        String nickname,
        String content,
        Instant createdAt,
        boolean isMine
) {}
