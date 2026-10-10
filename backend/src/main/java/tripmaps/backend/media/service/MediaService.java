package tripmaps.backend.media.service;

import net.coobird.thumbnailator.Thumbnails;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.*;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;
import tripmaps.backend.config.S3Helper;
import tripmaps.backend.fcm.FcmService;
import tripmaps.backend.media.api.dto.*;
import tripmaps.backend.media.domain.*;
import tripmaps.backend.media.repository.CommentRepository;
import tripmaps.backend.media.repository.MediaLikeRepository;
import tripmaps.backend.media.repository.MediaRepository;
import tripmaps.backend.trip.domain.Trip;
import tripmaps.backend.trip.domain.TripMember;
import tripmaps.backend.trip.domain.TripRole;
import tripmaps.backend.trip.repository.TripMemberRepository;
import tripmaps.backend.trip.repository.TripRepository;
import tripmaps.backend.user.repository.UserRepository;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class MediaService {

    private static final Logger log = LoggerFactory.getLogger(MediaService.class);

    private final S3Presigner presigner;
    private final S3Client s3Client;
    private final S3Helper s3Helper;
    private final MediaRepository mediaRepository;
    private final MediaLikeRepository mediaLikeRepository;
    private final CommentRepository commentRepository;
    private final TripMemberRepository tripMemberRepository;
    private final TripRepository tripRepository;
    private final UserRepository userRepository;
    private final FcmService fcmService;

    // 업로드 가능한 MIME 타입 목록
    private static final Set<String> ALLOWED_MEDIA_TYPES = Set.of(
            "image/png",
            "image/jpeg",
            "image/jpg",
            "video/mp4",
            "video/quicktime"
    );

    @Value("${app.s3.bucket}")
    private String bucket;

    public MediaService(S3Presigner presigner, S3Client s3Client, S3Helper s3Helper,
                        MediaRepository mediaRepository, MediaLikeRepository mediaLikeRepository,
                        CommentRepository commentRepository,
                        TripMemberRepository tripMemberRepository, TripRepository tripRepository,
                        UserRepository userRepository, FcmService fcmService) {
        this.presigner = presigner;
        this.s3Client = s3Client;
        this.s3Helper = s3Helper;
        this.mediaRepository = mediaRepository;
        this.mediaLikeRepository = mediaLikeRepository;
        this.commentRepository = commentRepository;
        this.tripMemberRepository = tripMemberRepository;
        this.tripRepository = tripRepository;
        this.userRepository = userRepository;
        this.fcmService = fcmService;
    }

    // 파일 업로드 (S3 url 만들어줌)
    @Transactional(readOnly = true)
    public MediaPresignResponse presignUpload(Long tripId, Long requesterUserId, MediaPresignRequest req) {
        TripMember member = tripMemberRepository.findByTripIdAndUserId(tripId, requesterUserId)
                .orElseThrow(() -> new IllegalStateException("해당 여행의 멤버가 아닙니다."));

        if (member.getRole() == TripRole.VIEWER) {
            throw new IllegalStateException("업로드 권한이 없습니다.");
        }

        String safeName = req.originalFileName().replaceAll("[^a-zA-Z0-9._-]", "_");
        String key = "trips/" + tripId + "/" + UUID.randomUUID() + "_" + safeName;

        PutObjectRequest objectRequest = PutObjectRequest.builder()
                .bucket(bucket)
                .key(key)
//        (Content-Type 임시 제거)
//                .contentType(req.contentType())
                .build();

        PutObjectPresignRequest presignRequest = PutObjectPresignRequest.builder()
                .signatureDuration(Duration.ofMinutes(10))
                .putObjectRequest(objectRequest)
                .build();

        String url = presigner.presignPutObject(presignRequest).url().toString();
        return new MediaPresignResponse(url, key, "PUT");
    }

    // 파일 서버 검증
    @Transactional
    public MediaResponse complete(Long tripId, Long requesterUserId, MediaCompleteRequest req) {
        // 멤버인지 체크
        TripMember member = tripMemberRepository.findByTripIdAndUserId(tripId, requesterUserId)
                .orElseThrow(() -> new IllegalStateException("해당 여행의 멤버가 아닙니다."));

        if (member.getRole() == TripRole.VIEWER) {
            throw new IllegalStateException("업로드 권한이 없습니다.");
        }

        // S3 HEAD 검증: 파일 존재 여부 + Content-Type 체크
        HeadObjectRequest headReq = HeadObjectRequest.builder()
                .bucket(bucket)
                .key(req.storageKey())
                .build();

        HeadObjectResponse headRes;
        try {
            headRes = s3Client.headObject(headReq);
        } catch (NoSuchKeyException e) {
            throw new IllegalStateException("업로드된 파일을 찾을 수 없습니다.");
        } catch (S3Exception e) {
            // awsErrorDetails()는 서비스 응답이 없는 경우(네트워크 오류 등) null일 수 있음 → null-safe 처리
            String detail = e.awsErrorDetails() != null ? e.awsErrorDetails().errorMessage() : e.getMessage();
            throw new IllegalStateException("파일 검증 실패: " + e.statusCode() + " / " + detail);
        } catch (Exception e) {
            throw new IllegalStateException("파일 검증 중 오류가 발생했습니다: " + e.getMessage());
        }

        String contentType = headRes.contentType();
        if (!ALLOWED_MEDIA_TYPES.contains(contentType)) {
            throw new IllegalStateException("지원하지 않는 파일 형식입니다.");
        }

//      미디어 타입 enum 변환
        MediaType type;
        try {
            type = MediaType.valueOf(req.type());
        } catch (Exception e) {
            throw new IllegalStateException("미디어 타입이 올바르지 않습니다.");
        }

        // 이미지: 서버에서 썸네일 생성 / 영상: Flutter가 업로드한 thumbnailKey 사용
        String thumbnailKey = req.thumbnailKey();
        if (contentType.startsWith("image/") && thumbnailKey == null) {
            thumbnailKey = generateImageThumbnail(tripId, req.storageKey());
        }

        boolean isZeroCoord = req.lat() != null && req.lng() != null
                && req.lat() == 0.0 && req.lng() == 0.0;
        Double lat = isZeroCoord ? null : req.lat();
        Double lng = isZeroCoord ? null : req.lng();

        Media media = new Media(
                tripId,
                requesterUserId,
                type,
                req.takenAt(),
                lat,
                lng,
                req.addressText(),
                req.storageKey(),
                thumbnailKey,
                MediaStatus.READY
        );

        Media saved = mediaRepository.save(media);

        // 업로드 완료 알림 (같은 Trip 멤버 전체)
        try {
            fcmService.notifyUpload(tripId, requesterUserId, type);
        } catch (Exception e) {
            log.warn("FCM 알림 발송 실패: {}", e.getMessage());
        }

        String uploaderNickname = userRepository.findById(requesterUserId)
                .map(u -> u.getNickname())
                .orElse(null);
        return toResponse(saved, uploaderNickname, null, 0L, false, 0L);
    }

    // 미디어 목록 조회
    @Transactional(readOnly = true)
    public List<MediaResponse> list(Long tripId, Long requesterUserId) {
        boolean isMember = tripMemberRepository.existsByTripIdAndUserId(tripId, requesterUserId);
        if (!isMember) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "해당 여행의 멤버만 조회할 수 있습니다.");
        }

        List<Media> mediaList = mediaRepository.findAllByTripIdOrderByTakenAtAscIdAsc(tripId);

        List<Long> uploaderIds = mediaList.stream()
                .map(Media::getUploaderId)
                .filter(Objects::nonNull)
                .distinct()
                .toList();
        Map<Long, String> nicknameMap = new java.util.HashMap<>();
        userRepository.findAllByIdIn(uploaderIds)
                .forEach(u -> { if (u.getNickname() != null) nicknameMap.put(u.getId(), u.getNickname()); });

        List<Long> mediaIds = mediaList.stream().map(Media::getId).toList();
        Set<Long> likedIds = mediaLikeRepository.findAllByMediaIdInAndUserId(mediaIds, requesterUserId)
                .stream().map(MediaLike::getMediaId).collect(Collectors.toSet());
        Map<Long, Long> likeCountMap = buildLikeCountMap(mediaIds);
        Map<Long, Long> commentCountMap = buildCommentCountMap(mediaIds);

        return mediaList.stream()
                .map(m -> toResponse(m, nicknameMap.get(m.getUploaderId()), null,
                        likeCountMap.getOrDefault(m.getId(), 0L), likedIds.contains(m.getId()),
                        commentCountMap.getOrDefault(m.getId(), 0L)))
                .toList();
    }

    // 좋아요 토글
    @Transactional
    public MediaResponse toggleLike(Long tripId, Long mediaId, Long userId) {
        if (!tripMemberRepository.existsByTripIdAndUserId(tripId, userId)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "해당 여행의 멤버가 아닙니다.");
        }
        Media media = mediaRepository.findById(mediaId)
                .filter(m -> m.getTripId().equals(tripId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "미디어를 찾을 수 없습니다."));

        boolean wasLiked = mediaLikeRepository.existsByMediaIdAndUserId(mediaId, userId);
        if (wasLiked) {
            mediaLikeRepository.deleteByMediaIdAndUserId(mediaId, userId);
        } else {
            mediaLikeRepository.save(new MediaLike(mediaId, userId));
            try {
                fcmService.notifyLike(tripId, mediaId, media.getUploaderId(), userId, media.getType());
            } catch (Exception e) {
                log.warn("FCM 알림 발송 실패: {}", e.getMessage());
            }
        }

        long likeCount = mediaLikeRepository.countByMediaId(mediaId);
        boolean isLiked = mediaLikeRepository.existsByMediaIdAndUserId(mediaId, userId);
        long commentCount = commentRepository.countGroupByMediaIds(List.of(mediaId)).stream()
                .mapToLong(row -> (Long) row[1]).sum();
        return toResponse(media, null, null, likeCount, isLiked, commentCount);
    }

    // 파일 다운로드
    @Transactional(readOnly = true)
    public MediaDownloadUrlResponse getDownloadUrl(Long mediaId, Long requesterUserId) {
        Media media = mediaRepository.findById(mediaId)
                .orElseThrow(() -> new IllegalStateException("미디어를 찾을 수 없습니다."));

        TripMember member = tripMemberRepository.findByTripIdAndUserId(media.getTripId(), requesterUserId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "해당 여행의 멤버만 다운로드할 수 있습니다."));

        if (member.getRole() == TripRole.VIEWER) {
            throw new IllegalStateException("다운로드 권한이 없습니다.");
        }

        if (media.getStatus() != MediaStatus.READY) {
            throw new IllegalStateException("아직 준비되지 않은 미디어입니다.");
        }

        String url = createPresignedGetUrl(media.getStorageKey());
        return new MediaDownloadUrlResponse(url, "GET", 600);
    }

    // 미디어 위치 수동 지정
    @Transactional
    public MediaResponse updateLocation(Long tripId, Long mediaId, Long requesterUserId,
                                        Double lat, Double lng) {
        TripMember member = tripMemberRepository.findByTripIdAndUserId(tripId, requesterUserId)
                .orElseThrow(() -> new IllegalStateException("해당 여행의 멤버가 아닙니다."));
        if (member.getRole() == TripRole.VIEWER) {
            throw new IllegalStateException("위치 수정 권한이 없습니다.");
        }

        Media media = mediaRepository.findById(mediaId)
                .filter(m -> m.getTripId().equals(tripId))
                .orElseThrow(() -> new IllegalStateException("미디어를 찾을 수 없습니다."));

        media.updateLocation(lat, lng);
        String uploaderNickname = media.getUploaderId() != null
                ? userRepository.findById(media.getUploaderId()).map(u -> u.getNickname()).orElse(null)
                : null;
        long likeCount = mediaLikeRepository.countByMediaId(mediaId);
        boolean isLiked = mediaLikeRepository.existsByMediaIdAndUserId(mediaId, requesterUserId);
        long commentCount = commentRepository.countGroupByMediaIds(List.of(mediaId)).stream()
                .mapToLong(row -> (Long) row[1]).sum();
        return toResponse(media, uploaderNickname, null, likeCount, isLiked, commentCount);
    }

    // 미디어 삭제 (S3 + DB)
    @Transactional
    public void deleteMedia(Long tripId, Long mediaId, Long requesterUserId) {
        TripMember member = tripMemberRepository.findByTripIdAndUserId(tripId, requesterUserId)
                .orElseThrow(() -> new IllegalStateException("해당 여행의 멤버가 아닙니다."));
        if (member.getRole() == TripRole.VIEWER) {
            throw new IllegalStateException("삭제 권한이 없습니다.");
        }

        Media media = mediaRepository.findById(mediaId)
                .filter(m -> m.getTripId().equals(tripId))
                .orElseThrow(() -> new IllegalStateException("미디어를 찾을 수 없습니다."));

        // S3 삭제
        deleteS3Object(media.getStorageKey());
        if (media.getThumbnailKey() != null) {
            deleteS3Object(media.getThumbnailKey());
        }

        mediaRepository.delete(media);
    }

    private void deleteS3Object(String key) {
        s3Helper.deleteObject(key);
    }

    private String createPresignedGetUrl(String storageKey) {
        return s3Helper.createPresignedGetUrl(storageKey);
    }


    // 나의 미디어 갤러리 — 업로더 기준 전체 미디어 (tripTitle 포함)
    @Transactional(readOnly = true)
    public List<MediaResponse> listMyMedia(Long userId) {
        List<Media> mediaList = mediaRepository
                .findAllByUploaderIdAndStatusOrderByTakenAtDescIdDesc(userId, MediaStatus.READY);

        List<Long> tripIds = mediaList.stream().map(Media::getTripId).distinct().toList();
        Map<Long, String> tripTitleMap = tripIds.isEmpty() ? Map.of() :
                tripRepository.findAllByIdInOrderByIdDesc(tripIds).stream()
                        .collect(Collectors.toMap(Trip::getId, Trip::getTitle));

        List<Long> mediaIds = mediaList.stream().map(Media::getId).toList();
        Set<Long> likedIds = mediaLikeRepository.findAllByMediaIdInAndUserId(mediaIds, userId)
                .stream().map(MediaLike::getMediaId).collect(Collectors.toSet());
        Map<Long, Long> likeCountMap = buildLikeCountMap(mediaIds);
        Map<Long, Long> commentCountMap = buildCommentCountMap(mediaIds);

        return mediaList.stream()
                .map(m -> toResponse(m, null, tripTitleMap.get(m.getTripId()),
                        likeCountMap.getOrDefault(m.getId(), 0L), likedIds.contains(m.getId()),
                        commentCountMap.getOrDefault(m.getId(), 0L)))
                .toList();
    }

    private Map<Long, Long> buildLikeCountMap(List<Long> mediaIds) {
        if (mediaIds.isEmpty()) return Map.of();
        return mediaLikeRepository.countGroupByMediaIds(mediaIds).stream()
                .collect(Collectors.toMap(
                        row -> (Long) row[0],
                        row -> (Long) row[1]
                ));
    }

    private Map<Long, Long> buildCommentCountMap(List<Long> mediaIds) {
        if (mediaIds.isEmpty()) return Map.of();
        return commentRepository.countGroupByMediaIds(mediaIds).stream()
                .collect(Collectors.toMap(
                        row -> (Long) row[0],
                        row -> (Long) row[1]
                ));
    }

    private MediaResponse toResponse(Media m, String uploaderNickname, String tripTitle,
                                     long likeCount, boolean isLiked, long commentCount) {
        String downloadUrl = null;
        String thumbnailUrl = null;

        if (m.getStatus() == MediaStatus.READY) {
            downloadUrl = createPresignedGetUrl(m.getStorageKey());
            if (m.getThumbnailKey() != null) {
                thumbnailUrl = createPresignedGetUrl(m.getThumbnailKey());
            }
        }

        return new MediaResponse(
                m.getId(),
                m.getType().name(),
                m.getTakenAt(),
                m.getLat(),
                m.getLng(),
                m.getAddressText(),
                m.getStorageKey(),
                m.getThumbnailKey(),
                m.getStatus().name(),
                downloadUrl,
                thumbnailUrl,
                uploaderNickname,
                tripTitle,
                likeCount,
                isLiked,
                commentCount
        );
    }

    /**
     * S3에서 원본 이미지를 내려받아 400×400 썸네일을 생성하고 MinIO에 업로드.
     * 실패 시 null 반환 (썸네일 없이 정상 저장).
     */
    private String generateImageThumbnail(Long tripId, String storageKey) {
        try {
            // 20MB 초과 이미지는 OOM 방지를 위해 썸네일 생성 스킵
            HeadObjectResponse head = s3Client.headObject(
                    HeadObjectRequest.builder().bucket(bucket).key(storageKey).build()
            );
            if (head.contentLength() != null && head.contentLength() > 20 * 1024 * 1024) {
                log.warn("썸네일 생성 스킵 - 파일 크기 초과 ({}bytes, storageKey={})", head.contentLength(), storageKey);
                return null;
            }

            // 1) 원본 이미지 다운로드
            byte[] original = s3Client.getObjectAsBytes(
                    GetObjectRequest.builder().bucket(bucket).key(storageKey).build()
            ).asByteArray();

            // 2) Thumbnailator 리사이즈 (최대 400px, JPEG 출력)
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            Thumbnails.of(new ByteArrayInputStream(original))
                    .size(400, 400)
                    .keepAspectRatio(true)
                    .outputFormat("JPEG")
                    .toOutputStream(out);

            byte[] thumbBytes = out.toByteArray();

            // 3) MinIO에 업로드
            String thumbKey = "thumbnails/" + tripId + "/" + UUID.randomUUID() + "_thumb.jpg";
            s3Client.putObject(
                    PutObjectRequest.builder()
                            .bucket(bucket)
                            .key(thumbKey)
                            .contentType("image/jpeg")
                            .contentLength((long) thumbBytes.length)
                            .build(),
                    RequestBody.fromBytes(thumbBytes)
            );

            return thumbKey;
        } catch (Throwable e) {
            log.warn("썸네일 생성 실패 (storageKey={}): {}", storageKey, e.getMessage());
            return null;
        }
    }
}
