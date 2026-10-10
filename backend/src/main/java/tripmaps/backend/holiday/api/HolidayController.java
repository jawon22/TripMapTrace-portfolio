package tripmaps.backend.holiday.api;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import tripmaps.backend.holiday.repository.HolidayRepository;

import java.util.List;

@RestController
@RequestMapping("/api/v1/holidays")
public class HolidayController {

    private final HolidayRepository holidayRepository;

    public HolidayController(HolidayRepository holidayRepository) {
        this.holidayRepository = holidayRepository;
    }

    /** 현재 DB에 저장된 공휴일 전체 반환 (YYYY-MM-DD 문자열 리스트) */
    @GetMapping
    public List<String> getHolidays() {
        return holidayRepository.findAll().stream()
                .map(h -> h.getDate().toString())
                .toList();
    }
}
