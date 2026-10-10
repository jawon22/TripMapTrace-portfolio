package tripmaps.backend.media.domain;

import jakarta.persistence.*;
import org.hibernate.annotations.CreationTimestamp;

import java.io.Serializable;
import java.time.Instant;

@Entity
@Table(name = "media_likes")
@IdClass(MediaLike.PK.class)
public class MediaLike {

    @Id
    @Column(name = "media_id")
    private Long mediaId;

    @Id
    @Column(name = "user_id")
    private Long userId;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected MediaLike() {}

    public MediaLike(Long mediaId, Long userId) {
        this.mediaId = mediaId;
        this.userId = userId;
    }

    public Long getMediaId() { return mediaId; }
    public Long getUserId() { return userId; }

    public static class PK implements Serializable {
        private Long mediaId;
        private Long userId;

        public PK() {}

        public PK(Long mediaId, Long userId) {
            this.mediaId = mediaId;
            this.userId = userId;
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof PK pk)) return false;
            return java.util.Objects.equals(mediaId, pk.mediaId) &&
                   java.util.Objects.equals(userId, pk.userId);
        }

        @Override
        public int hashCode() {
            return java.util.Objects.hash(mediaId, userId);
        }
    }
}
