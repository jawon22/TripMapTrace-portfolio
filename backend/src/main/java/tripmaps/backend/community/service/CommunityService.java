package tripmaps.backend.community.service;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import tripmaps.backend.community.api.dto.*;
import tripmaps.backend.community.domain.TripComment;
import tripmaps.backend.community.domain.TripLike;
import tripmaps.backend.community.repository.TripCommentRepository;
import tripmaps.backend.community.repository.TripLikeRepository;
import tripmaps.backend.config.S3Helper;
import tripmaps.backend.media.domain.Media;
import tripmaps.backend.media.domain.MediaStatus;
import tripmaps.backend.media.repository.MediaRepository;
import tripmaps.backend.trip.domain.Trip;
import tripmaps.backend.trip.repository.TripMemberRepository;
import tripmaps.backend.trip.repository.TripRepository;
import tripmaps.backend.user.domain.User;
import tripmaps.backend.user.repository.UserRepository;

import java.util.*;
import java.util.stream.Collectors;

@Service
public class CommunityService {

    private final TripRepository tripRepository;
    private final TripMemberRepository tripMemberRepository;
    private final MediaRepository mediaRepository;
    private final TripLikeRepository tripLikeRepository;
    private final TripCommentRepository tripCommentRepository;
    private final UserRepository userRepository;
    private final S3Helper s3Helper;

    public CommunityService(TripRepository tripRepository, TripMemberRepository tripMemberRepository,
                            MediaRepository mediaRepository, TripLikeRepository tripLikeRepository,
                            TripCommentRepository tripCommentRepository, UserRepository userRepository,
                            S3Helper s3Helper) {
        this.tripRepository = tripRepository;
        this.tripMemberRepository = tripMemberRepository;
        this.mediaRepository = mediaRepository;
        this.tripLikeRepository = tripLikeRepository;
        this.tripCommentRepository = tripCommentRepository;
        this.userRepository = userRepository;
        this.s3Helper = s3Helper;
    }

    @Transactional(readOnly = true)
    public CommunityPageResponse<CommunityTripSummary> listPublicTrips(
            int page, int size, String sort, String keyword, boolean onlyLiked, Long requesterId) {

        List<Trip> trips = (keyword != null && !keyword.isBlank())
                ? tripRepository.findByIsPublicTrueAndTitleContainingIgnoreCaseOrderByCreatedAtDesc(keyword)
                : tripRepository.findByIsPublicTrueOrderByCreatedAtDesc();

        List<Long> tripIds = trips.stream().map(Trip::getId).toList();

        if (tripIds.isEmpty()) {
            return new CommunityPageResponse<>(List.of(), page, size, 0, true);
        }

        // Batch load counts
        Map<Long, Long> likeCounts = toCountMap(tripLikeRepository.countGroupByTripIds(tripIds));
        Map<Long, Long> commentCounts = toCountMap(tripCommentRepository.countGroupByTripIds(tripIds));
        Set<Long> likedByUser = (requesterId != null)
                ? tripLikeRepository.findAllByTripIdInAndUserId(tripIds, requesterId)
                    .stream().map(TripLike::getTripId).collect(Collectors.toSet())
                : Set.of();

        List<CommunityTripSummary> summaries = trips.stream().map(t -> {
            long likeCount = likeCounts.getOrDefault(t.getId(), 0L);
            long commentCount = commentCounts.getOrDefault(t.getId(), 0L);
            boolean isLiked = likedByUser.contains(t.getId());
            int memberCount = (int) tripMemberRepository.countByTripId(t.getId());
            int mediaCount = (int) mediaRepository.countByTripIdAndStatus(t.getId(), MediaStatus.READY);
            String coverUrl = buildCoverUrl(t);
            return new CommunityTripSummary(t.getId(), t.getTitle(), t.getStartDate(), t.getEndDate(),
                    coverUrl, memberCount, mediaCount, likeCount, commentCount, isLiked);
        }).collect(Collectors.toList());

        // Filter by liked
        if (onlyLiked) {
            summaries = summaries.stream().filter(CommunityTripSummary::isLiked).collect(Collectors.toList());
        }

        // Sort
        if ("popular".equals(sort)) {
            summaries.sort(Comparator.comparingLong(CommunityTripSummary::likeCount).reversed());
        } else if ("comments".equals(sort)) {
            summaries.sort(Comparator.comparingLong(CommunityTripSummary::commentCount).reversed());
        }

        long total = summaries.size();
        int from = page * size;
        int to = (int) Math.min(from + size, total);
        List<CommunityTripSummary> paged = (from >= total) ? List.of() : summaries.subList(from, to);

        return new CommunityPageResponse<>(new ArrayList<>(paged), page, size, total, to >= total);
    }

    @Transactional(readOnly = true)
    public CommunityTripDetail getTripDetail(Long tripId, Long requesterId) {
        Trip trip = tripRepository.findById(tripId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "여행을 찾을 수 없습니다."));
        if (!trip.isPublic()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "비공개 여행입니다.");
        }

        List<Media> mediaList = mediaRepository.findAllByTripIdAndStatusOrderByTakenAtAscIdAsc(tripId, MediaStatus.READY);
        long likeCount = tripLikeRepository.countByTripId(tripId);
        long commentCount = tripCommentRepository.countByTripId(tripId);
        boolean isLiked = (requesterId != null) && tripLikeRepository.existsByTripIdAndUserId(tripId, requesterId);
        int memberCount = (int) tripMemberRepository.countByTripId(tripId);

        List<CommunityMediaItem> mediaItems = mediaList.stream().map(m -> {
            String thumbnailUrl = m.getThumbnailKey() != null
                    ? s3Helper.createPresignedGetUrl(m.getThumbnailKey())
                    : null;
            String downloadUrl = s3Helper.createPresignedGetUrl(m.getStorageKey());
            return new CommunityMediaItem(m.getId(), m.getType().name(), thumbnailUrl, downloadUrl,
                    m.getTakenAt(), m.getLat(), m.getLng());
        }).toList();

        List<TripComment> recent = tripCommentRepository.findTop3ByTripIdOrderByCreatedAtDesc(tripId);
        List<Long> userIds = recent.stream().map(TripComment::getUserId).distinct().toList();
        Map<Long, String> nicknameMap = userRepository.findAllByIdIn(userIds).stream()
                .collect(Collectors.toMap(User::getId,
                        u -> u.getNickname() != null ? u.getNickname() : "닉네임 없음"));

        List<CommunityCommentResponse> recentComments = recent.stream()
                .sorted(Comparator.comparing(TripComment::getCreatedAt))
                .map(c -> new CommunityCommentResponse(
                        c.getId(),
                        nicknameMap.getOrDefault(c.getUserId(), "닉네임 없음"),
                        c.getContent(),
                        c.getCreatedAt(),
                        Objects.equals(c.getUserId(), requesterId)
                )).toList();

        String coverUrl = buildCoverUrl(trip);
        return new CommunityTripDetail(trip.getId(), trip.getTitle(), trip.getStartDate(), trip.getEndDate(),
                coverUrl, memberCount, likeCount, commentCount, isLiked, mediaItems, recentComments);
    }

    @Transactional
    public boolean toggleLike(Long tripId, Long requesterId) {
        Trip trip = tripRepository.findById(tripId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "여행을 찾을 수 없습니다."));
        if (!trip.isPublic()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "비공개 여행입니다.");
        }

        if (tripLikeRepository.existsByTripIdAndUserId(tripId, requesterId)) {
            tripLikeRepository.deleteByTripIdAndUserId(tripId, requesterId);
            return false;
        } else {
            tripLikeRepository.save(new TripLike(tripId, requesterId));
            return true;
        }
    }

    @Transactional
    public CommunityCommentResponse addComment(Long tripId, String content, Long requesterId) {
        Trip trip = tripRepository.findById(tripId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "여행을 찾을 수 없습니다."));
        if (!trip.isPublic()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "비공개 여행입니다.");
        }
        if (content == null || content.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "댓글 내용을 입력해 주세요.");
        }
        TripComment comment = tripCommentRepository.save(new TripComment(tripId, requesterId, content.trim()));
        User user = userRepository.findById(requesterId).orElse(null);
        String nickname = (user != null && user.getNickname() != null) ? user.getNickname() : "닉네임 없음";
        return new CommunityCommentResponse(comment.getId(), nickname, comment.getContent(), comment.getCreatedAt(), true);
    }

    @Transactional
    public CommunityCommentResponse updateComment(Long tripId, Long commentId, String content, Long requesterId) {
        TripComment comment = tripCommentRepository.findById(commentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "댓글을 찾을 수 없습니다."));
        if (!comment.getTripId().equals(tripId)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "해당 여행의 댓글이 아닙니다.");
        }
        if (!comment.getUserId().equals(requesterId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "본인 댓글만 수정할 수 있습니다.");
        }
        if (content == null || content.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "댓글 내용을 입력해 주세요.");
        }
        comment.updateContent(content.trim());
        User user = userRepository.findById(requesterId).orElse(null);
        String nickname = (user != null && user.getNickname() != null) ? user.getNickname() : "닉네임 없음";
        return new CommunityCommentResponse(comment.getId(), nickname, comment.getContent(), comment.getCreatedAt(), true);
    }

    @Transactional
    public void deleteComment(Long tripId, Long commentId, Long requesterId) {
        TripComment comment = tripCommentRepository.findById(commentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "댓글을 찾을 수 없습니다."));
        if (!comment.getTripId().equals(tripId)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "해당 여행의 댓글이 아닙니다.");
        }
        if (!comment.getUserId().equals(requesterId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "본인 댓글만 삭제할 수 있습니다.");
        }
        tripCommentRepository.delete(comment);
    }

    @Transactional(readOnly = true)
    public List<CommunityCommentResponse> getComments(Long tripId, Long requesterId) {
        Trip trip = tripRepository.findById(tripId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "여행을 찾을 수 없습니다."));
        if (!trip.isPublic()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "비공개 여행입니다.");
        }

        List<TripComment> comments = tripCommentRepository.findAllByTripIdOrderByCreatedAtAsc(tripId);
        List<Long> userIds = comments.stream().map(TripComment::getUserId).distinct().toList();
        Map<Long, String> nicknameMap = userRepository.findAllByIdIn(userIds).stream()
                .collect(Collectors.toMap(User::getId,
                        u -> u.getNickname() != null ? u.getNickname() : "닉네임 없음"));

        return comments.stream().map(c -> new CommunityCommentResponse(
                c.getId(),
                nicknameMap.getOrDefault(c.getUserId(), "닉네임 없음"),
                c.getContent(),
                c.getCreatedAt(),
                Objects.equals(c.getUserId(), requesterId)
        )).toList();
    }

    // ── helpers ───────────────────────────────────────

    private String buildCoverUrl(Trip t) {
        try {
            Media coverMedia = null;
            if (t.getCoverMediaId() != null) {
                coverMedia = mediaRepository.findById(t.getCoverMediaId())
                        .filter(m -> m.getStatus() == MediaStatus.READY && m.getTripId().equals(t.getId()))
                        .orElse(null);
            }
            if (coverMedia == null) {
                coverMedia = mediaRepository
                        .findFirstByTripIdAndStatusOrderByTakenAtAscIdAsc(t.getId(), MediaStatus.READY)
                        .orElse(null);
            }
            if (coverMedia == null) return null;
            String key = coverMedia.getThumbnailKey() != null ? coverMedia.getThumbnailKey() : coverMedia.getStorageKey();
            return s3Helper.createPresignedGetUrl(key);
        } catch (Exception ignored) {
            return null;
        }
    }

    private Map<Long, Long> toCountMap(List<Object[]> rows) {
        Map<Long, Long> map = new HashMap<>();
        for (Object[] row : rows) {
            map.put((Long) row[0], (Long) row[1]);
        }
        return map;
    }
}
