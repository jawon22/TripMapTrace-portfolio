package tripmaps.backend.media.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.Instant;

public record MediaCompleteRequest(
        @NotNull String type,          // PHOTO | VIDEO
        @NotNull Instant takenAt,
        Double lat,
        Double lng,
        String addressText,
        @NotBlank String storageKey,
        String thumbnailKey            // Flutter가 업로드한 영상 썸네일 키 (nullable)
) {}
