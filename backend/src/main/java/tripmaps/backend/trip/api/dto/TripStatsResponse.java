package tripmaps.backend.trip.api.dto;

import java.util.List;

public record TripStatsResponse(
    double distanceKm,
    int dayCount,
    int locationCount,
    int photoCount,
    int videoCount,
    List<MemberUploadStat> memberStats
) {
    public record MemberUploadStat(Long userId, String nickname, int count) {}
}
