package tripmaps.backend.invitation.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import tripmaps.backend.trip.domain.TripRole;

import java.time.Instant;

@Entity
@Table(name = "trip_invitations")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class TripInvitation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "trip_id", nullable = false)
    private Long tripId;

    @Column(name = "inviter_user_id", nullable = false)
    private Long inviterUserId;

    @Column(name = "invitee_user_id", nullable = false)
    private Long inviteeUserId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private InvitationStatus status;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private TripRole role;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "responded_at")
    private Instant respondedAt;

    public TripInvitation(Long tripId, Long inviterUserId, Long inviteeUserId, TripRole role) {
        this.tripId = tripId;
        this.inviterUserId = inviterUserId;
        this.inviteeUserId = inviteeUserId;
        this.role = role;
        this.status = InvitationStatus.PENDING;
    }

    public void accept() {
        this.status = InvitationStatus.ACCEPTED;
        this.respondedAt = Instant.now();
    }

    public void decline() {
        this.status = InvitationStatus.DECLINED;
        this.respondedAt = Instant.now();
    }
}
