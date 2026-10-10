package tripmaps.backend.media.api.dto;

import jakarta.validation.constraints.NotNull;

public record MediaLocationRequest(
        @NotNull Double lat,
        @NotNull Double lng
) {}
