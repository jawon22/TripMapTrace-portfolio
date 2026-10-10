package tripmaps.backend.config;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.Map;

/**
 * 전역 예외 핸들러.
 *
 * <p>서비스 계층이 잘못된 요청·권한 거부 등을 {@link IllegalStateException}/
 * {@link IllegalArgumentException}으로 던지는데, 핸들러가 없으면 Spring 기본 동작으로
 * 500 Internal Server Error가 되어 클라이언트가 "권한 없음"을 "서버 오류"로 오인한다.
 * 이를 400 Bad Request로 매핑한다.
 *
 * <p>주의: {@code ResponseStatusException}(서비스가 직접 403/404 등 상태코드를 지정한 경우),
 * {@code MethodArgumentNotValidException}(@Valid 검증 실패) 등은 의도적으로 처리하지 않는다.
 * Spring 기본 resolver가 올바른 상태코드를 유지하므로 가로채면 오히려 회귀가 발생한다.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler({IllegalStateException.class, IllegalArgumentException.class})
    public ResponseEntity<Map<String, String>> handleBadRequest(RuntimeException e) {
        return ResponseEntity
                .status(HttpStatus.BAD_REQUEST)
                .body(Map.of("message", e.getMessage() != null ? e.getMessage() : "잘못된 요청입니다."));
    }
}
