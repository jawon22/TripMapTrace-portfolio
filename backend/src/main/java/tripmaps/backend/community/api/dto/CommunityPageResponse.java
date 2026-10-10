package tripmaps.backend.community.api.dto;

import java.util.List;

public record CommunityPageResponse<T>(
        List<T> content,
        int page,
        int size,
        long totalElements,
        boolean last
) {}
