package tripmaps.backend.community.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import tripmaps.backend.community.domain.TripLike;

import java.util.List;

public interface TripLikeRepository extends JpaRepository<TripLike, TripLike.PK> {

    long countByTripId(Long tripId);

    boolean existsByTripIdAndUserId(Long tripId, Long userId);

    void deleteByTripIdAndUserId(Long tripId, Long userId);

    List<TripLike> findAllByTripIdInAndUserId(List<Long> tripIds, Long userId);

    @Query("SELECT tl.tripId, COUNT(tl) FROM TripLike tl WHERE tl.tripId IN :tripIds GROUP BY tl.tripId")
    List<Object[]> countGroupByTripIds(@Param("tripIds") List<Long> tripIds);
}
