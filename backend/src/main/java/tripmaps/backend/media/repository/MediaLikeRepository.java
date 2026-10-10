package tripmaps.backend.media.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import tripmaps.backend.media.domain.MediaLike;

import java.util.List;

public interface MediaLikeRepository extends JpaRepository<MediaLike, MediaLike.PK> {

    long countByMediaId(Long mediaId);

    boolean existsByMediaIdAndUserId(Long mediaId, Long userId);

    void deleteByMediaIdAndUserId(Long mediaId, Long userId);

    List<MediaLike> findAllByMediaIdInAndUserId(List<Long> mediaIds, Long userId);

    @Query("SELECT ml.mediaId, COUNT(ml) FROM MediaLike ml WHERE ml.mediaId IN :mediaIds GROUP BY ml.mediaId")
    List<Object[]> countGroupByMediaIds(@Param("mediaIds") List<Long> mediaIds);
}
