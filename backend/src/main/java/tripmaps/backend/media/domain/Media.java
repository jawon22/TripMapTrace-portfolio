package tripmaps.backend.media.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;

@Entity
@Table(name = "media")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Media {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "trip_id", nullable = false)
    private Long tripId;

    @Column(name = "uploader_id")
    private Long uploaderId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private MediaType type;

    @Column(name = "taken_at", nullable = false)
    private Instant takenAt;

    private Double lat;
    private Double lng;

    @Column(name = "address_text", length = 255)
    private String addressText;

    @Column(name = "storage_key", nullable = false, length = 500)
    private String storageKey;

    @Column(name = "thumbnail_key", length = 500)
    private String thumbnailKey;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private MediaStatus status;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public Media(Long tripId, Long uploaderId, MediaType type, Instant takenAt,
                 Double lat, Double lng, String addressText,
                 String storageKey, String thumbnailKey, MediaStatus status) {
        this.tripId = tripId;
        this.uploaderId = uploaderId;
        this.type = type;
        this.takenAt = takenAt;
        this.lat = lat;
        this.lng = lng;
        this.addressText = addressText;
        this.storageKey = storageKey;
        this.thumbnailKey = thumbnailKey;
        this.status = status;
    }

    public void markReady() {
        this.status = MediaStatus.READY;
    }

    public void updateThumbnailKey(String thumbnailKey) {
        this.thumbnailKey = thumbnailKey;
    }

    public void updateLocation(Double lat, Double lng) {
        this.lat = lat;
        this.lng = lng;
    }
}
