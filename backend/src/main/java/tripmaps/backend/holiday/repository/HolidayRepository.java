package tripmaps.backend.holiday.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import tripmaps.backend.holiday.domain.Holiday;

public interface HolidayRepository extends JpaRepository<Holiday, Long> {
}
