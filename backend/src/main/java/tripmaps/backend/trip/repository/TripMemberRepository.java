package tripmaps.backend.trip.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import tripmaps.backend.trip.domain.TripMember;

import java.util.List;
import java.util.Optional;

public interface TripMemberRepository extends JpaRepository<TripMember, Long> {

    Optional<TripMember> findByTripIdAndUserId(Long tripId, Long userId);

    boolean existsByTripIdAndUserId(Long tripId, Long userId);

    List<TripMember> findAllByTripIdOrderByIdAsc(Long tripId);

    List<TripMember> findAllByUserId(Long userId);

    long countByTripId(Long tripId);

    void deleteAllByTripId(Long tripId);
}
