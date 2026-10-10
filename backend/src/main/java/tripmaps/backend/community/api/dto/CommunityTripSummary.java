package tripmaps.backend.community.api.dto;

import java.time.LocalDate;

public record CommunityTripSummary(
        Long id,
        String title,
        LocalDate startDate,
        LocalDate endDate,
        String coverThumbnailUrl,
        int memberCount,
        int mediaCount,
        long likeCount,
        long commentCount,
        boolean isLiked
) {}
