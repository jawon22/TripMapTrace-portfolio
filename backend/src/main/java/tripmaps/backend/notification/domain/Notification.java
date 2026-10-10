package tripmaps.backend.notification.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;

@Entity
@Table(name = "notifications")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Notification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private NotificationType type;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(nullable = false, length = 500)
    private String body;

    @Column(name = "is_read", nullable = false)
    private boolean isRead = false;

    @Column(name = "target_trip_id")
    private Long targetTripId;

    @Column(name = "target_media_id")
    private Long targetMediaId;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public Notification(Long userId, NotificationType type, String title, String body,
                        Long targetTripId, Long targetMediaId) {
        this.userId = userId;
        this.type = type;
        this.title = title;
        this.body = body;
        this.targetTripId = targetTripId;
        this.targetMediaId = targetMediaId;
    }

    public void markRead() {
        this.isRead = true;
    }
}
