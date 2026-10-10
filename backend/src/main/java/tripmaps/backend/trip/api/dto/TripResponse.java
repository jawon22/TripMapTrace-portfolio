package tripmaps.backend.trip.api.dto;

import java.time.Instant;
import java.time.LocalDate;

public record TripResponse(
        Long id,
        String title,
        LocalDate startDate,
        LocalDate endDate,
        Long createdBy,
        Instant createdAt,
        String myRole,
        String coverThumbnailUrl,
        int memberCount,
        int mediaCount,
        boolean isPublic
) {}
