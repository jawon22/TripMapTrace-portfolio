package tripmaps.backend.trip.api.dto;

import jakarta.validation.constraints.NotBlank;

public record RoleChangeRequest(@NotBlank String role) {}
