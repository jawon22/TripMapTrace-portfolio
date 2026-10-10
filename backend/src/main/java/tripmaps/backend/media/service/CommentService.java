package tripmaps.backend.media.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import tripmaps.backend.fcm.FcmService;
import tripmaps.backend.media.api.dto.CommentRequest;
import tripmaps.backend.media.api.dto.CommentResponse;
import tripmaps.backend.media.domain.Comment;
import tripmaps.backend.media.repository.CommentRepository;
import tripmaps.backend.media.repository.MediaRepository;
import tripmaps.backend.trip.repository.TripMemberRepository;
import tripmaps.backend.user.repository.UserRepository;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class CommentService {

    private static final Logger log = LoggerFactory.getLogger(CommentService.class);

    private final CommentRepository commentRepository;
    private final MediaRepository mediaRepository;
    private final UserRepository userRepository;
    private final TripMemberRepository tripMemberRepository;
    private final FcmService fcmService;

    public CommentService(CommentRepository commentRepository,
                          MediaRepository mediaRepository,
                          UserRepository userRepository,
                          TripMemberRepository tripMemberRepository,
                          FcmService fcmService) {
        this.commentRepository = commentRepository;
        this.mediaRepository = mediaRepository;
        this.userRepository = userRepository;
        this.tripMemberRepository = tripMemberRepository;
        this.fcmService = fcmService;
    }

    @Transactional(readOnly = true)
    public List<CommentResponse> list(Long tripId, Long mediaId, Long userId) {
        requireMember(tripId, userId);
        requireMediaInTrip(tripId, mediaId);

        List<Comment> comments = commentRepository.findAllByMediaIdOrderByCreatedAtAsc(mediaId);

        List<Long> userIds = comments.stream().map(Comment::getUserId).distinct().toList();
        Map<Long, String> nicknameMap = new HashMap<>();
        userRepository.findAllByIdIn(userIds)
                .forEach(u -> nicknameMap.put(u.getId(), u.getNickname()));

        return comments.stream()
                .map(c -> new CommentResponse(
                        c.getId(),
                        c.getMediaId(),
                        c.getUserId(),
                        nicknameMap.get(c.getUserId()),
                        c.getContent(),
                        c.getCreatedAt()
                ))
                .toList();
    }

    @Transactional
    public CommentResponse create(Long tripId, Long mediaId, Long userId, CommentRequest req) {
        requireMember(tripId, userId);
        requireMediaInTrip(tripId, mediaId);

        Comment saved = commentRepository.save(new Comment(mediaId, userId, req.content()));

        try {
            fcmService.notifyComment(tripId, mediaId, userId, req.content());
        } catch (Exception e) {
            log.warn("FCM 알림 발송 실패: {}", e.getMessage());
        }

        String nickname = userRepository.findById(userId)
                .map(u -> u.getNickname())
                .orElse(null);

        return new CommentResponse(saved.getId(), saved.getMediaId(), saved.getUserId(),
                nickname, saved.getContent(), saved.getCreatedAt());
    }

    @Transactional
    public CommentResponse update(Long tripId, Long mediaId, Long commentId, Long userId, CommentRequest req) {
        requireMember(tripId, userId);

        Comment comment = commentRepository.findById(commentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "댓글을 찾을 수 없습니다."));

        if (!comment.getMediaId().equals(mediaId)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "해당 미디어의 댓글이 아닙니다.");
        }
        if (!comment.getUserId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "본인 댓글만 수정할 수 있습니다.");
        }

        comment.updateContent(req.content());

        String nickname = userRepository.findById(userId)
                .map(u -> u.getNickname())
                .orElse(null);

        return new CommentResponse(comment.getId(), comment.getMediaId(), comment.getUserId(),
                nickname, comment.getContent(), comment.getCreatedAt());
    }

    @Transactional
    public void delete(Long tripId, Long mediaId, Long commentId, Long userId) {
        requireMember(tripId, userId);

        Comment comment = commentRepository.findById(commentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "댓글을 찾을 수 없습니다."));

        if (!comment.getMediaId().equals(mediaId)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "해당 미디어의 댓글이 아닙니다.");
        }
        if (!comment.getUserId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "본인 댓글만 삭제할 수 있습니다.");
        }

        commentRepository.delete(comment);
    }

    // ── private helpers ───────────────────────────────

    /** 해당 여행의 멤버인지 검증 (비멤버의 댓글 조회·작성·수정·삭제 차단 — IDOR 방어). */
    private void requireMember(Long tripId, Long userId) {
        if (!tripMemberRepository.existsByTripIdAndUserId(tripId, userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "해당 여행의 멤버만 접근할 수 있습니다.");
        }
    }

    /** 미디어가 해당 여행에 속하는지 검증. */
    private void requireMediaInTrip(Long tripId, Long mediaId) {
        mediaRepository.findById(mediaId)
                .filter(m -> m.getTripId().equals(tripId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "미디어를 찾을 수 없습니다."));
    }
}
