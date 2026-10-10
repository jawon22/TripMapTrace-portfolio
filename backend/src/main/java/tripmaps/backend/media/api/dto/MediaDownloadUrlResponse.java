package tripmaps.backend.media.api.dto;

public record MediaDownloadUrlResponse(
    String url,
    String method,
    int expiresInSeconds
) {}
