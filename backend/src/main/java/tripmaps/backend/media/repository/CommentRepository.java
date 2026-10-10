package tripmaps.backend.media.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import tripmaps.backend.media.domain.Comment;

import java.util.List;

public interface CommentRepository extends JpaRepository<Comment, Long> {

    List<Comment> findAllByMediaIdOrderByCreatedAtAsc(Long mediaId);

    @Query("SELECT c.mediaId, COUNT(c) FROM Comment c WHERE c.mediaId IN :mediaIds GROUP BY c.mediaId")
    List<Object[]> countGroupByMediaIds(@Param("mediaIds") List<Long> mediaIds);

    @Query("SELECT DISTINCT c.userId FROM Comment c WHERE c.mediaId = :mediaId AND c.userId != :excludeUserId")
    List<Long> findDistinctUserIdsExcluding(@Param("mediaId") Long mediaId, @Param("excludeUserId") Long excludeUserId);
}
