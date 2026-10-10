package tripmaps.backend.user.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.HeadObjectRequest;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;
import tripmaps.backend.config.S3Helper;
import tripmaps.backend.media.domain.MediaStatus;
import tripmaps.backend.media.repository.MediaRepository;
import tripmaps.backend.trip.domain.Trip;
import tripmaps.backend.trip.domain.TripMember;
import tripmaps.backend.trip.domain.TripRole;
import tripmaps.backend.trip.repository.TripMemberRepository;
import tripmaps.backend.trip.repository.TripRepository;
import tripmaps.backend.user.api.dto.*;
import tripmaps.backend.user.domain.User;
import tripmaps.backend.user.repository.UserRepository;

import java.time.Duration;
import java.util.List;
import java.util.UUID;

@Service
@Transactional(readOnly = true)
public class UserService {

    private final UserRepository userRepository;
    private final TripMemberRepository tripMemberRepository;
    private final TripRepository tripRepository;
    private final MediaRepository mediaRepository;
    private final PasswordEncoder passwordEncoder;
    private final S3Presigner presigner;
    private final S3Client s3Client;
    private final S3Helper s3Helper;

    @Value("${app.s3.bucket}")
    private String bucket;

    public UserService(UserRepository userRepository,
                       TripMemberRepository tripMemberRepository,
                       TripRepository tripRepository,
                       MediaRepository mediaRepository,
                       PasswordEncoder passwordEncoder,
                       S3Presigner presigner,
                       S3Client s3Client,
                       S3Helper s3Helper) {
        this.userRepository = userRepository;
        this.tripMemberRepository = tripMemberRepository;
        this.tripRepository = tripRepository;
        this.mediaRepository = mediaRepository;
        this.passwordEncoder = passwordEncoder;
        this.presigner = presigner;
        this.s3Client = s3Client;
        this.s3Helper = s3Helper;
    }

    public UserResponse getMe(Long userId) {
        User user = findUser(userId);
        return toResponse(user);
    }

    public UserStatsResponse getStats(Long userId) {
        int tripCount = (int) tripMemberRepository.findAllByUserId(userId).stream().count();
        int mediaCount = (int) mediaRepository.countByUploaderIdAndStatus(userId, MediaStatus.READY);
        return new UserStatsResponse(tripCount, mediaCount, 0);
    }

    @Transactional(readOnly = true)
    public AvatarPresignResponse presignAvatar(Long userId, AvatarPresignRequest req) {
        findUser(userId); // 존재 확인

        String ext = extractExt(req.originalFileName());
        String key = "avatars/" + userId + "/" + UUID.randomUUID() + ext;

        PutObjectRequest putReq = PutObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .build();

        String uploadUrl = presigner.presignPutObject(
                PutObjectPresignRequest.builder()
                        .signatureDuration(Duration.ofMinutes(10))
                        .putObjectRequest(putReq)
                        .build()
        ).url().toString();

        return new AvatarPresignResponse(uploadUrl, key);
    }

    @Transactional
    public UserResponse completeAvatar(Long userId, AvatarCompleteRequest req) {
        User user = findUser(userId);

        try {
            s3Client.headObject(HeadObjectRequest.builder()
                    .bucket(bucket)
                    .key(req.storageKey())
                    .build());
        } catch (NoSuchKeyException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "업로드된 파일을 찾을 수 없습니다.");
        }

        user.updateProfileImageUrl(req.storageKey());
        return toResponse(user);
    }

    @Transactional
    public void updateFcmToken(Long userId, FcmTokenRequest req) {
        User user = findUser(userId);
        user.updateFcmToken(req.fcmToken());
    }

    @Transactional(readOnly = true)
    public NotificationSettingsResponse getNotificationSettings(Long userId) {
        User user = findUser(userId);
        return new NotificationSettingsResponse(user.isNotifyUpload(), user.isNotifyJoin(), user.isNotifyRoleChange());
    }

    @Transactional
    public NotificationSettingsResponse updateNotificationSettings(Long userId, NotificationSettingsRequest req) {
        User user = findUser(userId);
        user.updateNotificationSettings(req.notifyUpload(), req.notifyJoin(), req.notifyRoleChange());
        return new NotificationSettingsResponse(user.isNotifyUpload(), user.isNotifyJoin(), user.isNotifyRoleChange());
    }

    @Transactional
    public void changePassword(Long userId, PasswordChangeRequest req) {
        User user = findUser(userId);
        if (user.getProvider() != null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "소셜 로그인 계정은 비밀번호를 변경할 수 없습니다.");
        }
        if (!passwordEncoder.matches(req.currentPassword(), user.getPasswordHash())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "현재 비밀번호가 올바르지 않습니다.");
        }
        user.updatePasswordHash(passwordEncoder.encode(req.newPassword()));
    }

    @Transactional
    public UserResponse updateNickname(Long userId, NicknameUpdateRequest req) {
        String nickname = req.nickname() == null ? "" : req.nickname().trim();
        if (nickname.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "닉네임을 입력해주세요.");
        }
        if (nickname.length() > 50) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "닉네임은 50자 이하여야 합니다.");
        }

        User user = findUser(userId);
        user.updateNickname(nickname);
        return toResponse(user);
    }

    @Transactional(readOnly = true)
    public List<OwnerTripResponse> getOwnerTrips(Long userId) {
        List<Long> ownerTripIds = tripMemberRepository.findAllByUserId(userId).stream()
                .filter(m -> m.getRole() == TripRole.OWNER)
                .map(m -> m.getTripId())
                .toList();
        if (ownerTripIds.isEmpty()) return List.of();
        return tripRepository.findAllByIdInOrderByIdDesc(ownerTripIds).stream()
                .map(t -> new OwnerTripResponse(t.getId(), t.getTitle()))
                .toList();
    }

    @Transactional
    public void completeOnboarding(Long userId) {
        findUser(userId).completeOnboarding();
    }

    @Transactional
    public void deleteAccount(Long userId) {
        findUser(userId);
        // trip_members: ON DELETE CASCADE (DB가 자동 처리)
        // media.uploader_id: ON DELETE SET NULL (DB가 자동 처리)
        // trips.created_by: ON DELETE SET NULL (DB가 자동 처리)
        // password_reset_tokens: ON DELETE CASCADE (DB가 자동 처리)
        userRepository.deleteById(userId);
    }

    // ── private helpers ───────────────────────────────

    private User findUser(Long userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "유저를 찾을 수 없습니다."));
    }

    private UserResponse toResponse(User user) {
        String profileImageUrl = user.getProfileImageUrl();
        // 소셜 로그인 URL은 "http"로 시작, S3 key는 "avatars/"로 시작 → presigned GET URL 변환
        if (profileImageUrl != null && !profileImageUrl.startsWith("http")) {
            profileImageUrl = s3Helper.createPresignedGetUrl(profileImageUrl);
        }
        return new UserResponse(user.getId(), user.getEmail(), user.getNickname(), profileImageUrl, user.getProvider());
    }

    private String extractExt(String fileName) {
        int idx = fileName.lastIndexOf('.');
        return idx >= 0 ? "." + fileName.substring(idx + 1).toLowerCase() : "";
    }
}
