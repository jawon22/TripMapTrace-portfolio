package tripmaps.backend.trip.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "trips")
@Getter
@NoArgsConstructor (access = AccessLevel.PROTECTED)
public class Trip {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(name = "start_date")
    private LocalDate startDate;

    @Column(name = "end_date")
    private LocalDate endDate;

    @Column(name = "created_by")
    private Long createdBy;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "cover_media_id")
    private Long coverMediaId;

    @Column(name = "is_public", nullable = false)
    private boolean isPublic = false;

    // 의미 있는 생성자만 제공
    public Trip(String title, LocalDate startDate, LocalDate endDate, Long createdBy) {
        this.title = title;
        this.startDate = startDate;
        this.endDate = endDate;
        this.createdBy = createdBy;
        this.isPublic = false;
    }

    public void update(String title, LocalDate startDate, LocalDate endDate) {
        this.title = title;
        this.startDate = startDate;
        this.endDate = endDate;
    }

    public void setCoverMediaId(Long coverMediaId) {
        this.coverMediaId = coverMediaId;
    }

    public void setPublic(boolean isPublic) {
        this.isPublic = isPublic;
    }
}
