package tripmaps.backend.community.api.dto;

import java.time.Instant;

public record CommunityMediaItem(
        Long id,
        String type,
        String thumbnailUrl,
        String downloadUrl,
        Instant takenAt,
        Double lat,
        Double lng
) {}
