package tripmaps.backend.community.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import tripmaps.backend.community.domain.TripComment;

import java.util.List;

public interface TripCommentRepository extends JpaRepository<TripComment, Long> {

    long countByTripId(Long tripId);

    List<TripComment> findTop3ByTripIdOrderByCreatedAtDesc(Long tripId);

    List<TripComment> findAllByTripIdOrderByCreatedAtAsc(Long tripId);

    @Query("SELECT tc.tripId, COUNT(tc) FROM TripComment tc WHERE tc.tripId IN :tripIds GROUP BY tc.tripId")
    List<Object[]> countGroupByTripIds(@Param("tripIds") List<Long> tripIds);
}
