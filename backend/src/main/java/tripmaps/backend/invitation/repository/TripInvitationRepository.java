package tripmaps.backend.invitation.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import tripmaps.backend.invitation.domain.InvitationStatus;
import tripmaps.backend.invitation.domain.TripInvitation;

import java.util.List;

public interface TripInvitationRepository extends JpaRepository<TripInvitation, Long> {

    boolean existsByTripIdAndInviteeUserIdAndStatus(Long tripId, Long inviteeUserId, InvitationStatus status);

    List<TripInvitation> findAllByInviteeUserIdAndStatusOrderByIdDesc(Long inviteeUserId, InvitationStatus status);
}
