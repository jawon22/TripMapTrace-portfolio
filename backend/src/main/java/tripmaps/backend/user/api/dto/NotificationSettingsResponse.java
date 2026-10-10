package tripmaps.backend.user.api.dto;

public record NotificationSettingsResponse(
        boolean notifyUpload,
        boolean notifyJoin,
        boolean notifyRoleChange
) {}
