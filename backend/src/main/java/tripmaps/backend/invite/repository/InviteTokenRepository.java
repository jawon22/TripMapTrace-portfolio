package tripmaps.backend.invite.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import tripmaps.backend.invite.domain.InviteToken;

import java.util.Optional;

public interface InviteTokenRepository extends JpaRepository<InviteToken, Long> {
    Optional<InviteToken> findByToken(String token);
    boolean existsByToken(String token);
    void deleteAllByTripId(Long tripId);
    Optional<InviteToken> findFirstByTripIdOrderByCreatedAtDesc(Long tripId);
}
