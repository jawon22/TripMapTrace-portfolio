package tripmaps.backend.media.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Entity
@Table(name = "comments")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Comment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long mediaId;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    public Comment(Long mediaId, Long userId, String content) {
        this.mediaId = mediaId;
        this.userId = userId;
        this.content = content;
        this.createdAt = Instant.now();
    }

    /** 댓글 내용 수정 (본인 댓글 한정 검증은 서비스 계층에서 수행) */
    public void updateContent(String content) {
        this.content = content;
    }
}
