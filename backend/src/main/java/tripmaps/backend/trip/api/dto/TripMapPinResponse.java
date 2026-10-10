package tripmaps.backend.trip.api.dto;

public record TripMapPinResponse(
        Long tripId,
        String title,
        String thumbnailUrl,
        Double lat,
        Double lng,
        int mediaCount,
        String myRole
) {}
