package tripmaps.backend.notification.api;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import tripmaps.backend.notification.api.dto.NotificationResponse;
import tripmaps.backend.notification.service.NotificationService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/notifications")
public class NotificationController {

    private final NotificationService notificationService;

    public NotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    private Long currentUserId(Authentication auth) {
        return (Long) auth.getPrincipal();
    }

    @GetMapping
    public List<NotificationResponse> list(Authentication auth) {
        return notificationService.list(currentUserId(auth));
    }

    @GetMapping("/unread-count")
    public long unreadCount(Authentication auth) {
        return notificationService.getUnreadCount(currentUserId(auth));
    }

    @PatchMapping("/{id}/read")
    public ResponseEntity<Void> markRead(@PathVariable Long id, Authentication auth) {
        notificationService.markRead(id, currentUserId(auth));
        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/read-all")
    public ResponseEntity<Void> markAllRead(Authentication auth) {
        notificationService.markAllRead(currentUserId(auth));
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id, Authentication auth) {
        notificationService.delete(id, currentUserId(auth));
        return ResponseEntity.noContent().build();
    }
}
