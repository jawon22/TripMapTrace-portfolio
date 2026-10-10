package tripmaps.backend.community.domain;

import jakarta.persistence.*;
import org.hibernate.annotations.CreationTimestamp;

import java.io.Serializable;
import java.time.Instant;

@Entity
@Table(name = "trip_likes")
@IdClass(TripLike.PK.class)
public class TripLike {

    @Id
    @Column(name = "trip_id")
    private Long tripId;

    @Id
    @Column(name = "user_id")
    private Long userId;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected TripLike() {}

    public TripLike(Long tripId, Long userId) {
        this.tripId = tripId;
        this.userId = userId;
    }

    public Long getTripId() { return tripId; }
    public Long getUserId() { return userId; }

    public static class PK implements Serializable {
        private Long tripId;
        private Long userId;

        public PK() {}

        public PK(Long tripId, Long userId) {
            this.tripId = tripId;
            this.userId = userId;
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof PK pk)) return false;
            return java.util.Objects.equals(tripId, pk.tripId) &&
                   java.util.Objects.equals(userId, pk.userId);
        }

        @Override
        public int hashCode() {
            return java.util.Objects.hash(tripId, userId);
        }
    }
}
