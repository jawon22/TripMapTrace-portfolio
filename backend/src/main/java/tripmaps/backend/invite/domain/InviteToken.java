package tripmaps.backend.invite.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;

@Entity
@Table(name = "invite_tokens")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class InviteToken {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "trip_id", nullable = false)
    private Long tripId;

    @Column(nullable = false, length = 128, unique = true)
    private String token;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "max_uses", nullable = false)
    private int maxUses;

    @Column(name = "used_count", nullable = false)
    private int usedCount;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public InviteToken(Long tripId, String token, Instant expiresAt, int maxUses) {
        this.tripId = tripId;
        this.token = token;
        this.expiresAt = expiresAt;
        this.maxUses = maxUses;
        this.usedCount = 0;
    }

    public boolean isExpired(Instant now) {
        return now.isAfter(expiresAt);
    }

    public boolean canUse() {
        return usedCount < maxUses;
    }

    public void increaseUsedCount() {
        this.usedCount += 1;
    }
}
