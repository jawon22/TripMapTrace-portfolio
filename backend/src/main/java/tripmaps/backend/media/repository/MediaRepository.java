package tripmaps.backend.media.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import tripmaps.backend.media.domain.Media;
import tripmaps.backend.media.domain.MediaStatus;

import java.util.List;
import java.util.Optional;

public interface MediaRepository extends JpaRepository<Media, Long> {

    List<Media> findAllByTripIdOrderByTakenAtAscIdAsc(Long tripId);

    void deleteAllByTripId(Long tripId);

    Optional<Media> findFirstByTripIdAndStatusAndLatIsNotNullOrderByTakenAtAsc(Long tripId, MediaStatus status);

    Optional<Media> findFirstByTripIdAndStatusOrderByTakenAtAscIdAsc(Long tripId, MediaStatus status);

    long countByTripIdAndStatus(Long tripId, MediaStatus status);

    List<Media> findAllByTripIdAndStatusOrderByTakenAtAscIdAsc(Long tripId, MediaStatus status);

    List<Media> findAllByUploaderIdAndStatusOrderByTakenAtDescIdDesc(Long uploaderId, MediaStatus status);

    long countByUploaderIdAndStatus(Long uploaderId, MediaStatus status);
}
