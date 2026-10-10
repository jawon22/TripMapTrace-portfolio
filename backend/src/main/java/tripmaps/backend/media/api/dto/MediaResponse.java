package tripmaps.backend.media.api.dto;

import java.time.Instant;

public record MediaResponse(
    Long id,
    String type,
    Instant takenAt,
    Double lat,
    Double lng,
    String addressText,
    String storageKey,
    String thumbnailKey,
    String status,
    String downloadUrl,
    String thumbnailUrl,
    String uploaderNickname,
    String tripTitle,
    long likeCount,
    boolean isLiked,
    long commentCount
) {}
