package tripmaps.backend.holiday.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;
import tripmaps.backend.holiday.domain.Holiday;
import tripmaps.backend.holiday.repository.HolidayRepository;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class HolidayBatchService {

    private static final Logger log = LoggerFactory.getLogger(HolidayBatchService.class);

    private static final String BASE_URL =
            "https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService";
    private static final String[] ENDPOINTS = {"getRestDeInfo", "getHoliDeInfo"};

    private final HolidayRepository holidayRepository;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Value("${app.holiday.api-key}")
    private String apiKey;

    public HolidayBatchService(HolidayRepository holidayRepository) {
        this.holidayRepository = holidayRepository;
    }

    /** 첫 배포 시 DB가 비어있으면 즉시 수집 */
    @PostConstruct
    public void initIfEmpty() {
        if (holidayRepository.count() == 0) {
            log.info("공휴일 데이터 없음 - 초기 수집 시작");
            refreshHolidays();
        }
    }

    /** 매년 1월 1일, 7월 1일 00:00 자동 갱신 */
    @Scheduled(cron = "0 0 0 1 1,7 *")
    @Transactional
    public void refreshHolidays() {
        log.info("공휴일 배치 시작");
        int currentYear = LocalDate.now().getYear();

        List<Holiday> holidays = fetchAll(currentYear, currentYear + 1);

        holidayRepository.deleteAllInBatch();
        holidayRepository.saveAll(holidays);

        log.info("공휴일 배치 완료 - {}건 저장", holidays.size());
    }

    // ── 내부 메서드 ─────────────────────────────────────────────────────────────

    private List<Holiday> fetchAll(int... years) {
        RestTemplate restTemplate = new RestTemplate();
        // date → name 맵으로 중복 제거 (두 endpoint에서 같은 날짜 올 수 있음)
        Map<LocalDate, String> map = new LinkedHashMap<>();

        for (int year : years) {
            for (String endpoint : ENDPOINTS) {
                try {
                    String url = UriComponentsBuilder
                            .fromHttpUrl(BASE_URL + "/" + endpoint)
                            .queryParam("serviceKey", apiKey)
                            .queryParam("solYear", year)
                            .queryParam("numOfRows", 100)
                            .queryParam("_type", "json")
                            .build()
                            .toUriString();

                    String body = restTemplate.getForObject(url, String.class);
                    parse(body).forEach(h -> map.putIfAbsent(h.getDate(), h.getName()));

                } catch (Exception e) {
                    log.warn("공휴일 API 호출 실패 (year={}, endpoint={}): {}",
                            year, endpoint, e.getMessage());
                }
            }
        }

        return map.entrySet().stream()
                .map(e -> new Holiday(e.getKey(), e.getValue()))
                .toList();
    }

    private List<Holiday> parse(String json) {
        List<Holiday> result = new ArrayList<>();
        try {
            JsonNode items = objectMapper.readTree(json)
                    .path("response").path("body").path("items");
            if (items.isMissingNode() || items.isNull()) return result;

            JsonNode item = items.path("item");
            if (item.isMissingNode() || item.isNull()) return result;

            Iterable<JsonNode> nodes = item.isArray() ? item : List.of(item);

            for (JsonNode node : nodes) {
                if (!"Y".equals(node.path("isHoliday").asText())) continue;

                String locdate = node.path("locdate").asText();
                if (locdate.length() != 8) continue;

                LocalDate date = LocalDate.of(
                        Integer.parseInt(locdate.substring(0, 4)),
                        Integer.parseInt(locdate.substring(4, 6)),
                        Integer.parseInt(locdate.substring(6, 8))
                );
                result.add(new Holiday(date, node.path("dateName").asText("공휴일")));
            }
        } catch (Exception e) {
            log.warn("공휴일 JSON 파싱 실패: {}", e.getMessage());
        }
        return result;
    }
}
