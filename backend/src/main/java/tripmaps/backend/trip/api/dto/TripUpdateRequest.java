package tripmaps.backend.trip.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

public record TripUpdateRequest(
        @NotBlank @Size(max = 200) String title,
        LocalDate startDate,
        LocalDate endDate
) {}
