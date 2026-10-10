package tripmaps.backend.notification.api.dto;

import tripmaps.backend.notification.domain.Notification;
import tripmaps.backend.notification.domain.NotificationType;

import java.time.Instant;

public record NotificationResponse(
        Long id,
        NotificationType type,
        String title,
        String body,
        boolean isRead,
        Long targetTripId,
        Long targetMediaId,
        Instant createdAt
) {
    public static NotificationResponse from(Notification n) {
        return new NotificationResponse(
                n.getId(), n.getType(), n.getTitle(), n.getBody(),
                n.isRead(), n.getTargetTripId(), n.getTargetMediaId(), n.getCreatedAt()
        );
    }
}
