package tripmaps.backend.fcm;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MulticastMessage;
import com.google.firebase.messaging.Notification;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import tripmaps.backend.media.domain.Media;
import tripmaps.backend.media.domain.MediaType;
import tripmaps.backend.media.repository.CommentRepository;
import tripmaps.backend.media.repository.MediaRepository;
import tripmaps.backend.notification.domain.NotificationType;
import tripmaps.backend.notification.service.NotificationService;
import tripmaps.backend.trip.domain.TripMember;
import tripmaps.backend.trip.domain.TripRole;
import tripmaps.backend.trip.repository.TripMemberRepository;
import tripmaps.backend.trip.repository.TripRepository;
import tripmaps.backend.user.domain.User;
import tripmaps.backend.user.repository.UserRepository;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Service
public class FcmService {

    private static final Logger log = LoggerFactory.getLogger(FcmService.class);

    private final TripMemberRepository tripMemberRepository;
    private final TripRepository tripRepository;
    private final UserRepository userRepository;
    private final MediaRepository mediaRepository;
    private final CommentRepository commentRepository;
    private final NotificationService notificationService;

    public FcmService(TripMemberRepository tripMemberRepository,
                      TripRepository tripRepository,
                      UserRepository userRepository,
                      MediaRepository mediaRepository,
                      CommentRepository commentRepository,
                      NotificationService notificationService) {
        this.tripMemberRepository = tripMemberRepository;
        this.tripRepository = tripRepository;
        this.userRepository = userRepository;
        this.mediaRepository = mediaRepository;
        this.commentRepository = commentRepository;
        this.notificationService = notificationService;
    }

    // ── 1. 미디어 업로드 완료 → 나를 제외한 Trip 전체 멤버 ─────────────────
    public void notifyUpload(Long tripId, Long uploaderId, MediaType mediaType) {
        String tripTitle = getTripTitle(tripId);
        String uploaderNickname = getNickname(uploaderId);
        String mediaLabel = mediaType == MediaType.VIDEO ? "영상 1개" : "사진 1장";
        String body = uploaderNickname + "님이 [" + tripTitle + "]에 " + mediaLabel + "을 올렸어요";
        String title = tripTitle;

        List<User> targets = getMembersExcept(tripId, uploaderId).stream()
                .filter(User::isNotifyUpload)
                .toList();

        List<Long> targetIds = targets.stream().map(User::getId).toList();
        try {
            notificationService.saveAll(targetIds, NotificationType.UPLOAD, title, body, tripId, null);
        } catch (Exception e) {
            log.warn("알림 DB 저장 실패: {}", e.getMessage());
        }
        sendMulticast(targets, title, body, "tripId", String.valueOf(tripId));
    }

    // ── 2. 멤버 초대 수락 (참여) → Trip OWNER ──────────────────────────────
    public void notifyJoin(Long tripId, Long joinedUserId) {
        String tripTitle = getTripTitle(tripId);
        String joinedNickname = getNickname(joinedUserId);
        String body = joinedNickname + "님이 [" + tripTitle + "]에 참여했습니다.";
        String title = tripTitle;

        User owner = getOwner(tripId);
        if (owner == null || !owner.isNotifyJoin()) return;

        try {
            notificationService.save(owner.getId(), NotificationType.JOIN, title, body, tripId, null);
        } catch (Exception e) {
            log.warn("알림 DB 저장 실패: {}", e.getMessage());
        }
        sendSingle(owner, title, body, "tripId", String.valueOf(tripId));
    }

    // ── 2-1. 직접 초대 요청 → 피초대자 ─────────────────────────────────────
    public void notifyInvitation(Long tripId, Long inviteeUserId, Long inviterUserId) {
        String tripTitle = getTripTitle(tripId);
        String inviterNickname = getNickname(inviterUserId);
        String title = "여행 초대";
        String body = inviterNickname + "님이 [" + tripTitle + "] 여행에 초대했습니다.";

        User invitee = userRepository.findById(inviteeUserId).orElse(null);
        if (invitee == null) return;

        try {
            notificationService.save(invitee.getId(), NotificationType.INVITE, title, body, tripId, null);
        } catch (Exception e) {
            log.warn("알림 DB 저장 실패: {}", e.getMessage());
        }
        sendSingle(invitee, title, body, "tripId", String.valueOf(tripId));
    }

    // ── 3. 멤버 자진 탈퇴 → Trip OWNER ────────────────────────────────────
    public void notifyLeave(Long tripId, Long leftUserId) {
        String tripTitle = getTripTitle(tripId);
        String leftNickname = getNickname(leftUserId);
        String body = leftNickname + "님이 [" + tripTitle + "]에서 탈퇴했습니다.";
        String title = tripTitle;

        User owner = getOwner(tripId);
        if (owner == null || !owner.isNotifyJoin()) return;

        try {
            notificationService.save(owner.getId(), NotificationType.LEAVE, title, body, tripId, null);
        } catch (Exception e) {
            log.warn("알림 DB 저장 실패: {}", e.getMessage());
        }
        sendSingle(owner, title, body, "tripId", String.valueOf(tripId));
    }

    // ── 4. 역할 변경 → 해당 멤버 ───────────────────────────────────────────
    public void notifyRoleChange(Long tripId, Long targetUserId, String newRole) {
        String tripTitle = getTripTitle(tripId);
        String title = tripTitle;

        userRepository.findById(targetUserId).ifPresent(user -> {
            if (!user.isNotifyRoleChange()) return;
            String roleKo = "EDITOR".equals(newRole) ? "편집자" : "뷰어";
            String body = "[" + tripTitle + "]에서 회원님의 역할이 " + roleKo + "로 변경되었습니다.";
            try {
                notificationService.save(user.getId(), NotificationType.ROLE_CHANGE, title, body, tripId, null);
            } catch (Exception e) {
                log.warn("알림 DB 저장 실패: {}", e.getMessage());
            }
            sendSingle(user, title, body, "tripId", String.valueOf(tripId));
        });
    }

    // ── 5. 강퇴 → 강퇴된 멤버 ─────────────────────────────────────────────
    public void notifyKick(Long tripId, Long kickedUserId) {
        String tripTitle = getTripTitle(tripId);
        String title = tripTitle;

        userRepository.findById(kickedUserId).ifPresent(user -> {
            if (!user.isNotifyRoleChange()) return;
            String body = "[" + tripTitle + "]에서 내보내졌습니다.";
            try {
                notificationService.save(user.getId(), NotificationType.KICK, title, body, null, null);
            } catch (Exception e) {
                log.warn("알림 DB 저장 실패: {}", e.getMessage());
            }
            sendSingle(user, title, body, null, null);
        });
    }

    // ── 6. 여행 삭제 → 전체 멤버 ──────────────────────────────────────────
    public void notifyTripDeleted(Long tripId, String tripTitle) {
        List<User> targets = getAllMembers(tripId).stream()
                .filter(User::isNotifyRoleChange)
                .toList();
        String body = "[" + tripTitle + "]이(가) 삭제되었습니다.";
        String title = tripTitle;

        List<Long> targetIds = targets.stream().map(User::getId).toList();
        try {
            notificationService.saveAll(targetIds, NotificationType.TRIP_DELETED, title, body, null, null);
        } catch (Exception e) {
            log.warn("알림 DB 저장 실패: {}", e.getMessage());
        }
        sendMulticast(targets, title, body, null, null);
    }

    // ── 7. 좋아요 → 미디어 업로더 (본인 제외) ─────────────────────────────
    public void notifyLike(Long tripId, Long mediaId, Long uploaderId, Long likerId, MediaType mediaType) {
        if (uploaderId == null || uploaderId.equals(likerId)) return;

        userRepository.findById(uploaderId).ifPresent(uploader -> {
            String likerNickname = getNickname(likerId);
            String mediaLabel = mediaType == MediaType.VIDEO ? "영상" : "사진";
            String body = likerNickname + "님이 내 " + mediaLabel + "을 좋아해요";
            String title = "좋아요";
            try {
                notificationService.save(uploaderId, NotificationType.LIKE, title, body, tripId, mediaId);
            } catch (Exception e) {
                log.warn("알림 DB 저장 실패: {}", e.getMessage());
            }
            sendSingle(uploader, title, body, "tripId", String.valueOf(tripId));
        });
    }

    // ── 8. 댓글 → 미디어 업로더 + 기존 댓글러 (본인 제외) ────────────────
    public void notifyComment(Long tripId, Long mediaId, Long commenterId, String commentContent) {
        Media media = mediaRepository.findById(mediaId).orElse(null);
        if (media == null) return;

        String commenterNickname = getNickname(commenterId);
        String preview = commentContent.length() > 30
                ? commentContent.substring(0, 30) + "..." : commentContent;
        String body = commenterNickname + "님이 댓글을 남겼어요: " + preview;
        String title = "댓글";

        Set<Long> recipientIds = new HashSet<>();
        if (media.getUploaderId() != null && !media.getUploaderId().equals(commenterId)) {
            recipientIds.add(media.getUploaderId());
        }
        commentRepository.findDistinctUserIdsExcluding(mediaId, commenterId)
                .forEach(recipientIds::add);

        if (recipientIds.isEmpty()) return;

        List<Long> recipientList = new ArrayList<>(recipientIds);
        try {
            notificationService.saveAll(recipientList, NotificationType.COMMENT, title, body, tripId, mediaId);
        } catch (Exception e) {
            log.warn("알림 DB 저장 실패: {}", e.getMessage());
        }
        List<User> recipients = userRepository.findAllByIdIn(recipientList);
        sendMulticast(recipients, title, body, "tripId", String.valueOf(tripId));
    }

    // ── 발송 헬퍼 ──────────────────────────────────────────────────────────

    private void sendSingle(User user, String title, String body, String dataKey, String dataValue) {
        if (!isFcmEnabled() || user.getFcmToken() == null) return;
        try {
            Message.Builder builder = Message.builder()
                    .setToken(user.getFcmToken())
                    .setNotification(Notification.builder().setTitle(title).setBody(body).build());
            if (dataKey != null && dataValue != null) {
                builder.putData(dataKey, dataValue);
            }
            FirebaseMessaging.getInstance().send(builder.build());
        } catch (Exception e) {
            log.warn("FCM 단건 발송 실패 (userId={}): {}", user.getId(), e.getMessage());
        }
    }

    private void sendMulticast(List<User> users, String title, String body, String dataKey, String dataValue) {
        if (!isFcmEnabled()) return;
        List<String> tokens = users.stream()
                .map(User::getFcmToken)
                .filter(t -> t != null && !t.isBlank())
                .toList();
        if (tokens.isEmpty()) return;

        try {
            MulticastMessage.Builder builder = MulticastMessage.builder()
                    .addAllTokens(tokens)
                    .setNotification(Notification.builder().setTitle(title).setBody(body).build());
            if (dataKey != null && dataValue != null) {
                builder.putData(dataKey, dataValue);
            }
            FirebaseMessaging.getInstance().sendEachForMulticast(builder.build());
        } catch (Exception e) {
            log.warn("FCM 멀티캐스트 발송 실패: {}", e.getMessage());
        }
    }

    private boolean isFcmEnabled() {
        return !FirebaseApp.getApps().isEmpty();
    }

    // ── 조회 헬퍼 ──────────────────────────────────────────────────────────

    private String getTripTitle(Long tripId) {
        return tripRepository.findById(tripId)
                .map(t -> t.getTitle())
                .orElse("여행");
    }

    private String getNickname(Long userId) {
        return userRepository.findById(userId)
                .map(u -> u.getNickname() != null ? u.getNickname() : u.getEmail())
                .orElse("알 수 없음");
    }

    private List<User> getMembersExcept(Long tripId, Long excludeUserId) {
        List<Long> userIds = tripMemberRepository.findAllByTripIdOrderByIdAsc(tripId).stream()
                .map(TripMember::getUserId)
                .filter(id -> !id.equals(excludeUserId))
                .toList();
        return userRepository.findAllByIdIn(userIds);
    }

    private List<User> getAllMembers(Long tripId) {
        List<Long> userIds = tripMemberRepository.findAllByTripIdOrderByIdAsc(tripId).stream()
                .map(TripMember::getUserId)
                .toList();
        return userRepository.findAllByIdIn(userIds);
    }

    private User getOwner(Long tripId) {
        return tripMemberRepository.findAllByTripIdOrderByIdAsc(tripId).stream()
                .filter(m -> m.getRole() == TripRole.OWNER)
                .findFirst()
                .flatMap(m -> userRepository.findById(m.getUserId()))
                .orElse(null);
    }
}
