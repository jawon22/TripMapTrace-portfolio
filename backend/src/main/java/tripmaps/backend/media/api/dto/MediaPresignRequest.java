package tripmaps.backend.media.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record MediaPresignRequest(
    @NotNull String type,          // PHOTO | VIDEO
    @NotBlank String originalFileName,
    @NotBlank String contentType
) {}
