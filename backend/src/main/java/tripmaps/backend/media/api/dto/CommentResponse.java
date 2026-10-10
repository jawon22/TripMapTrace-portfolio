package tripmaps.backend.media.api.dto;

import java.time.Instant;

public record CommentResponse(
    Long id,
    Long mediaId,
    Long userId,
    String nickname,
    String content,
    Instant createdAt
) {}
