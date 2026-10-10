package tripmaps.backend.media.api.dto;

public record MediaPresignResponse(
    String uploadUrl,
    String storageKey,
    String method
) {}
