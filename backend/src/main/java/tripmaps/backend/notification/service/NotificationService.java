package tripmaps.backend.notification.service;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import tripmaps.backend.notification.api.dto.NotificationResponse;
import tripmaps.backend.notification.domain.Notification;
import tripmaps.backend.notification.domain.NotificationType;
import tripmaps.backend.notification.repository.NotificationRepository;

import java.util.List;

@Service
public class NotificationService {

    private final NotificationRepository notificationRepository;

    public NotificationService(NotificationRepository notificationRepository) {
        this.notificationRepository = notificationRepository;
    }

    public void save(Long userId, NotificationType type, String title, String body,
                     Long targetTripId, Long targetMediaId) {
        notificationRepository.save(
                new Notification(userId, type, title, body, targetTripId, targetMediaId));
    }

    public void saveAll(List<Long> userIds, NotificationType type, String title, String body,
                        Long targetTripId, Long targetMediaId) {
        if (userIds.isEmpty()) return;
        List<Notification> list = userIds.stream()
                .map(uid -> new Notification(uid, type, title, body, targetTripId, targetMediaId))
                .toList();
        notificationRepository.saveAll(list);
    }

    @Transactional(readOnly = true)
    public List<NotificationResponse> list(Long userId) {
        return notificationRepository.findAllByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(NotificationResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public long getUnreadCount(Long userId) {
        return notificationRepository.countByUserIdAndIsReadFalse(userId);
    }

    @Transactional
    public void markRead(Long notificationId, Long userId) {
        Notification n = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "알림을 찾을 수 없습니다."));
        if (!n.getUserId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "본인 알림만 읽음 처리할 수 있습니다.");
        }
        n.markRead();
    }

    @Transactional
    public void markAllRead(Long userId) {
        notificationRepository.markAllReadByUserId(userId);
    }

    @Transactional
    public void delete(Long notificationId, Long userId) {
        Notification n = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "알림을 찾을 수 없습니다."));
        if (!n.getUserId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "본인 알림만 삭제할 수 있습니다.");
        }
        notificationRepository.delete(n);
    }
}
