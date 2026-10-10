package tripmaps.backend.community.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;

@Entity
@Table(name = "trip_comments")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class TripComment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "trip_id", nullable = false)
    private Long tripId;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public TripComment(Long tripId, Long userId, String content) {
        this.tripId = tripId;
        this.userId = userId;
        this.content = content;
    }

    public void updateContent(String content) {
        this.content = content;
    }
}
