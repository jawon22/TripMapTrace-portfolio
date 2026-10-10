package tripmaps.backend.community.api.dto;

import java.time.LocalDate;
import java.util.List;

public record CommunityTripDetail(
        Long id,
        String title,
        LocalDate startDate,
        LocalDate endDate,
        String coverThumbnailUrl,
        int memberCount,
        long likeCount,
        long commentCount,
        boolean isLiked,
        List<CommunityMediaItem> media,
        List<CommunityCommentResponse> recentComments
) {}
