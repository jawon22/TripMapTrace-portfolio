package tripmaps.backend.trip.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import tripmaps.backend.trip.domain.Trip;

import java.util.List;

public interface TripRepository extends JpaRepository<Trip, Long> {
    List<Trip> findAllByCreatedByOrderByIdDesc(Long createdBy);

    List<Trip> findAllByIdInOrderByIdDesc(List<Long> ids);

    List<Trip> findByIsPublicTrueOrderByCreatedAtDesc();

    List<Trip> findByIsPublicTrueAndTitleContainingIgnoreCaseOrderByCreatedAtDesc(String keyword);
}
