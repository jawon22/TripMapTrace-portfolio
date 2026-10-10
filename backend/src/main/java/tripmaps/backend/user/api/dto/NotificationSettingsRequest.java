package tripmaps.backend.user.api.dto;

public record NotificationSettingsRequest(
        boolean notifyUpload,
        boolean notifyJoin,
        boolean notifyRoleChange
) {}
