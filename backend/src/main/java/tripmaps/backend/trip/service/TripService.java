package tripmaps.backend.trip.service;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import tripmaps.backend.config.S3Helper;
import tripmaps.backend.fcm.FcmService;
import tripmaps.backend.invite.repository.InviteTokenRepository;
import tripmaps.backend.media.domain.Media;
import tripmaps.backend.media.domain.MediaStatus;
import tripmaps.backend.media.domain.MediaType;
import tripmaps.backend.media.repository.MediaRepository;
import tripmaps.backend.trip.api.dto.TripCreateRequest;
import tripmaps.backend.trip.api.dto.TripMapPinResponse;
import tripmaps.backend.trip.api.dto.TripMemberResponse;
import tripmaps.backend.trip.api.dto.TripResponse;
import tripmaps.backend.trip.api.dto.TripStatsResponse;
import tripmaps.backend.trip.api.dto.TripUpdateRequest;
import tripmaps.backend.trip.api.dto.VisibilityRequest;
import tripmaps.backend.trip.domain.Trip;
import tripmaps.backend.trip.domain.TripMember;
import tripmaps.backend.trip.domain.TripRole;
import tripmaps.backend.trip.repository.TripMemberRepository;
import tripmaps.backend.trip.repository.TripRepository;
import tripmaps.backend.user.domain.User;
import tripmaps.backend.user.repository.UserRepository;

import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class TripService {

    private final TripRepository tripRepository;
    private final TripMemberRepository tripMemberRepository;
    private final UserRepository userRepository;
    private final MediaRepository mediaRepository;
    private final InviteTokenRepository inviteTokenRepository;
    private final S3Helper s3Helper;
    private final FcmService fcmService;

    public TripService(TripRepository tripRepository, TripMemberRepository tripMemberRepository,
                       UserRepository userRepository, MediaRepository mediaRepository,
                       InviteTokenRepository inviteTokenRepository, S3Helper s3Helper,
                       FcmService fcmService) {
        this.tripRepository = tripRepository;
        this.tripMemberRepository = tripMemberRepository;
        this.userRepository = userRepository;
        this.mediaRepository = mediaRepository;
        this.inviteTokenRepository = inviteTokenRepository;
        this.s3Helper = s3Helper;
        this.fcmService = fcmService;
    }

    @Transactional
    public TripResponse createTrip(TripCreateRequest req, Long userId) {
        Trip trip = tripRepository.save(new Trip(req.title(), req.startDate(), req.endDate(), userId));
        tripMemberRepository.save(new TripMember(trip.getId(), userId, TripRole.OWNER));
        return toResponse(trip, TripRole.OWNER);
    }

    @Transactional(readOnly = true)
    public List<TripResponse> listMyTrips(Long userId) {
        List<TripMember> memberships = tripMemberRepository.findAllByUserId(userId);
        List<Long> tripIds = memberships.stream().map(TripMember::getTripId).toList();
        Map<Long, TripRole> roleMap = memberships.stream()
                .collect(Collectors.toMap(TripMember::getTripId, TripMember::getRole));

        return tripRepository.findAllByIdInOrderByIdDesc(tripIds).stream()
                .map(t -> {
                    TripRole role = roleMap.get(t.getId());
                    String coverUrl = buildCoverUrl(t);
                    int memberCount = (int) tripMemberRepository.countByTripId(t.getId());
                    int mediaCount = (int) mediaRepository.countByTripIdAndStatus(t.getId(), MediaStatus.READY);

                    return new TripResponse(
                            t.getId(), t.getTitle(), t.getStartDate(), t.getEndDate(),
                            t.getCreatedBy(), t.getCreatedAt(), role.name(),
                            coverUrl, memberCount, mediaCount, t.isPublic()
                    );
                })
                .toList();
    }

    @Transactional(readOnly = true)
    public List<TripMemberResponse> listMembers(Long tripId, Long requesterUserId) {
        boolean isMember = tripMemberRepository.existsByTripIdAndUserId(tripId, requesterUserId);
        if (!isMember) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "해당 여행의 멤버만 조회할 수 있습니다.");
        }

        List<TripMember> members = tripMemberRepository.findAllByTripIdOrderByIdAsc(tripId);
        List<Long> userIds = members.stream().map(TripMember::getUserId).toList();
        Map<Long, User> userMap = userRepository.findAllByIdIn(userIds).stream()
                .collect(Collectors.toMap(User::getId, u -> u));

        return members.stream()
                .map(m -> {
                    User user = userMap.get(m.getUserId());
                    String email = user != null ? user.getEmail() : "알 수 없음";
                    String nickname = user != null ? (user.getNickname() != null ? user.getNickname() : "닉네임 없음") : "닉네임 없음";
                    String rawImageUrl = user != null ? user.getProfileImageUrl() : null;
                    String profileImageUrl = null;
                    if (rawImageUrl != null) {
                        // 소셜 로그인 URL은 "http"로 시작, S3 key는 "avatars/"로 시작 → presigned GET URL 변환
                        profileImageUrl = rawImageUrl.startsWith("http")
                                ? rawImageUrl
                                : s3Helper.createPresignedGetUrl(rawImageUrl);
                    }

                    return new TripMemberResponse(
                            m.getId(),
                            m.getUserId(),
                            email,
                            nickname,
                            profileImageUrl,
                            m.getRole().name(),
                            m.getJoinedAt()
                    );
                })
                .toList();
    }

    @Transactional
    public void changeMemberRole(Long tripId, Long memberId, String newRole, Long requesterId) {
        TripMember requester = tripMemberRepository.findByTripIdAndUserId(tripId, requesterId)
                .orElseThrow(() -> new IllegalStateException("해당 여행의 멤버가 아닙니다."));
        if (requester.getRole() != TripRole.OWNER) {
            throw new IllegalStateException("역할 변경 권한이 없습니다.");
        }

        TripMember target = tripMemberRepository.findById(memberId)
                .filter(m -> m.getTripId().equals(tripId))
                .orElseThrow(() -> new IllegalStateException("멤버를 찾을 수 없습니다."));
        if (target.getRole() == TripRole.OWNER) {
            throw new IllegalStateException("OWNER의 역할은 변경할 수 없습니다.");
        }

        TripRole role;
        try {
            role = TripRole.valueOf(newRole);
        } catch (Exception e) {
            throw new IllegalStateException("올바르지 않은 역할입니다.");
        }
        if (role == TripRole.OWNER) {
            throw new IllegalStateException("OWNER로 역할을 변경할 수 없습니다.");
        }

        target.changeRole(role);

        // 역할 변경 알림 (해당 멤버에게)
        try {
            fcmService.notifyRoleChange(tripId, target.getUserId(), role.name());
        } catch (Exception e) {
            // 알림 실패가 메인 플로우에 영향 없도록
        }
    }

    @Transactional
    public void removeMember(Long tripId, Long memberId, Long requesterId) {
        TripMember requester = tripMemberRepository.findByTripIdAndUserId(tripId, requesterId)
                .orElseThrow(() -> new IllegalStateException("해당 여행의 멤버가 아닙니다."));
        if (requester.getRole() != TripRole.OWNER) {
            throw new IllegalStateException("멤버 삭제 권한이 없습니다.");
        }

        TripMember target = tripMemberRepository.findById(memberId)
                .filter(m -> m.getTripId().equals(tripId))
                .orElseThrow(() -> new IllegalStateException("멤버를 찾을 수 없습니다."));
        if (target.getRole() == TripRole.OWNER) {
            throw new IllegalStateException("OWNER는 강제 삭제할 수 없습니다.");
        }

        Long kickedUserId = target.getUserId();
        tripMemberRepository.delete(target);

        // 강퇴 알림 (강퇴된 멤버에게)
        try {
            fcmService.notifyKick(tripId, kickedUserId);
        } catch (Exception e) {
            // 알림 실패가 메인 플로우에 영향 없도록
        }
    }

    @Transactional
    public void leaveTrip(Long tripId, Long requesterId) {
        TripMember member = tripMemberRepository.findByTripIdAndUserId(tripId, requesterId)
                .orElseThrow(() -> new IllegalStateException("해당 여행의 멤버가 아닙니다."));
        if (member.getRole() == TripRole.OWNER) {
            throw new IllegalStateException("OWNER는 탈퇴할 수 없습니다. Trip을 삭제해 주세요.");
        }

        Long leftUserId = member.getUserId();
        tripMemberRepository.delete(member);

        // 자진 탈퇴 알림 (OWNER에게)
        try {
            fcmService.notifyLeave(tripId, leftUserId);
        } catch (Exception e) {
            // 알림 실패가 메인 플로우에 영향 없도록
        }
    }

    @Transactional
    public TripResponse updateTrip(Long tripId, TripUpdateRequest req, Long requesterId) {
        TripMember member = tripMemberRepository.findByTripIdAndUserId(tripId, requesterId)
                .orElseThrow(() -> new IllegalStateException("해당 여행의 멤버가 아닙니다."));
        if (member.getRole() != TripRole.OWNER) {
            throw new IllegalStateException("수정 권한이 없습니다.");
        }

        Trip trip = tripRepository.findById(tripId)
                .orElseThrow(() -> new IllegalStateException("여행을 찾을 수 없습니다."));
        trip.update(req.title(), req.startDate(), req.endDate());
        return toResponse(trip, TripRole.OWNER);
    }

    @Transactional
    public void deleteTrip(Long tripId, Long requesterId) {
        TripMember member = tripMemberRepository.findByTripIdAndUserId(tripId, requesterId)
                .orElseThrow(() -> new IllegalStateException("해당 여행의 멤버가 아닙니다."));
        if (member.getRole() != TripRole.OWNER) {
            throw new IllegalStateException("삭제 권한이 없습니다.");
        }

        Trip trip = tripRepository.findById(tripId)
                .orElseThrow(() -> new IllegalStateException("여행을 찾을 수 없습니다."));

        // 삭제 알림 — DB 삭제 전에 발송 (멤버 목록 조회 가능해야 함)
        try {
            fcmService.notifyTripDeleted(tripId, trip.getTitle());
        } catch (Exception e) {
            // 알림 실패가 메인 플로우에 영향 없도록
        }

        // S3 오브젝트 삭제 (storage_key + thumbnail_key)
        List<Media> mediaList = mediaRepository.findAllByTripIdOrderByTakenAtAscIdAsc(tripId);
        for (Media m : mediaList) {
            s3Helper.deleteObject(m.getStorageKey());
            if (m.getThumbnailKey() != null) {
                s3Helper.deleteObject(m.getThumbnailKey());
            }
        }

        // DB 삭제 (순서 중요: media → invite_tokens → trip_members → trips)
        mediaRepository.deleteAllByTripId(tripId);
        inviteTokenRepository.deleteAllByTripId(tripId);
        tripMemberRepository.deleteAllByTripId(tripId);
        tripRepository.deleteById(tripId);
    }

    @Transactional(readOnly = true)
    public List<TripMapPinResponse> getMapPins(Long userId) {
        List<TripMember> memberships = tripMemberRepository.findAllByUserId(userId);
        List<Long> tripIds = memberships.stream().map(TripMember::getTripId).toList();
        List<Trip> trips = tripRepository.findAllByIdInOrderByIdDesc(tripIds);

        List<TripMapPinResponse> pins = new ArrayList<>();
        for (Trip trip : trips) {
            mediaRepository.findFirstByTripIdAndStatusAndLatIsNotNullOrderByTakenAtAsc(
                    trip.getId(), MediaStatus.READY
            ).ifPresent(media -> {
                // 핀 썸네일은 홈탭과 동일하게 cover_media_id 우선 사용
                String thumbnailUrl = buildCoverUrl(trip);

                int mediaCount = (int) mediaRepository.countByTripIdAndStatus(
                        trip.getId(), MediaStatus.READY);

                TripRole myRole = memberships.stream()
                        .filter(m -> m.getTripId().equals(trip.getId()))
                        .map(TripMember::getRole)
                        .findFirst()
                        .orElse(TripRole.VIEWER);

                pins.add(new TripMapPinResponse(
                        trip.getId(),
                        trip.getTitle(),
                        thumbnailUrl,
                        media.getLat(),
                        media.getLng(),
                        mediaCount,
                        myRole.name()
                ));
            });
        }
        return pins;
    }

    // ── 통계 ──────────────────────────────────────────

    @Transactional(readOnly = true)
    public TripStatsResponse getTripStats(Long tripId, Long userId) {
        boolean isMember = tripMemberRepository.existsByTripIdAndUserId(tripId, userId);
        if (!isMember) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "해당 여행의 멤버만 조회할 수 있습니다.");
        }

        List<Media> readyMedia = mediaRepository
                .findAllByTripIdAndStatusOrderByTakenAtAscIdAsc(tripId, MediaStatus.READY);

        // GPS 좌표가 있는 미디어 (takenAt 순)
        List<Media> gpsMedia = readyMedia.stream()
                .filter(m -> m.getLat() != null && m.getLng() != null)
                .toList();

        // 총 이동 거리 (Haversine)
        double distanceKm = 0.0;
        for (int i = 1; i < gpsMedia.size(); i++) {
            distanceKm += haversineKm(
                    gpsMedia.get(i - 1).getLat(), gpsMedia.get(i - 1).getLng(),
                    gpsMedia.get(i).getLat(), gpsMedia.get(i).getLng()
            );
        }
        distanceKm = Math.round(distanceKm * 10.0) / 10.0;

        // 촬영 일수 (UTC 기준 distinct date)
        long dayCount = readyMedia.stream()
                .map(m -> m.getTakenAt().atZone(ZoneOffset.UTC).toLocalDate())
                .distinct()
                .count();

        // 방문 지역 수 (반경 500m 클러스터링)
        List<double[]> gpsPoints = gpsMedia.stream()
                .map(m -> new double[]{m.getLat(), m.getLng()})
                .toList();
        int locationCount = countLocations(gpsPoints);

        // 사진 / 영상 수
        long photoCount = readyMedia.stream()
                .filter(m -> m.getType() == MediaType.PHOTO).count();
        long videoCount = readyMedia.stream()
                .filter(m -> m.getType() == MediaType.VIDEO).count();

        // 멤버별 업로드 수
        Map<Long, Long> uploaderCounts = readyMedia.stream()
                .collect(Collectors.groupingBy(Media::getUploaderId, Collectors.counting()));

        Map<Long, String> nicknameMap = userRepository.findAllByIdIn(new ArrayList<>(uploaderCounts.keySet()))
                .stream()
                .collect(Collectors.toMap(
                        User::getId,
                        u -> u.getNickname() != null ? u.getNickname() : u.getEmail()
                ));

        List<TripStatsResponse.MemberUploadStat> memberStats = uploaderCounts.entrySet().stream()
                .map(e -> new TripStatsResponse.MemberUploadStat(
                        e.getKey(),
                        nicknameMap.getOrDefault(e.getKey(), "알 수 없음"),
                        e.getValue().intValue()
                ))
                .sorted(Comparator.comparingInt(TripStatsResponse.MemberUploadStat::count).reversed())
                .toList();

        return new TripStatsResponse(
                distanceKm, (int) dayCount, locationCount,
                (int) photoCount, (int) videoCount, memberStats
        );
    }

    // ── 커버 이미지 지정 ──────────────────────────────

    @Transactional
    public void setCover(Long tripId, Long mediaId, Long userId) {
        TripMember member = tripMemberRepository.findByTripIdAndUserId(tripId, userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "해당 여행의 멤버가 아닙니다."));
        if (member.getRole() == TripRole.VIEWER) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "커버 지정 권한이 없습니다.");
        }

        Media media = mediaRepository.findById(mediaId)
                .filter(m -> m.getTripId().equals(tripId) && m.getStatus() == MediaStatus.READY)
                .orElseThrow(() -> new IllegalStateException("미디어를 찾을 수 없습니다."));

        Trip trip = tripRepository.findById(tripId)
                .orElseThrow(() -> new IllegalStateException("여행을 찾을 수 없습니다."));
        trip.setCoverMediaId(media.getId());
        tripRepository.save(trip);
    }

    // ── helpers ───────────────────────────────────────

    private String buildCoverUrl(Trip t) {
        try {
            Media coverMedia = null;

            // cover_media_id 우선
            if (t.getCoverMediaId() != null) {
                coverMedia = mediaRepository.findById(t.getCoverMediaId())
                        .filter(m -> m.getStatus() == MediaStatus.READY
                                  && m.getTripId().equals(t.getId()))
                        .orElse(null);
            }

            // 폴백: 첫 번째 READY 미디어
            if (coverMedia == null) {
                coverMedia = mediaRepository
                        .findFirstByTripIdAndStatusOrderByTakenAtAscIdAsc(t.getId(), MediaStatus.READY)
                        .orElse(null);
            }

            if (coverMedia == null) return null;

            String key = coverMedia.getThumbnailKey() != null
                    ? coverMedia.getThumbnailKey()
                    : coverMedia.getStorageKey();
            return s3Helper.createPresignedGetUrl(key);
        } catch (Exception ignored) {
            return null;
        }
    }

    private static double haversineKm(double lat1, double lon1, double lat2, double lon2) {
        final double R = 6371.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    private static int countLocations(List<double[]> points) {
        List<double[]> centroids = new ArrayList<>();
        for (double[] p : points) {
            boolean found = false;
            for (double[] c : centroids) {
                if (haversineKm(p[0], p[1], c[0], c[1]) <= 0.5) {
                    found = true;
                    break;
                }
            }
            if (!found) centroids.add(p);
        }
        return centroids.size();
    }

    @Transactional
    public TripResponse setVisibility(Long tripId, boolean isPublic, Long requesterId) {
        TripMember member = tripMemberRepository.findByTripIdAndUserId(tripId, requesterId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "해당 여행의 멤버가 아닙니다."));
        if (member.getRole() != TripRole.OWNER) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "공개/비공개 설정 권한이 없습니다.");
        }

        Trip trip = tripRepository.findById(tripId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "여행을 찾을 수 없습니다."));
        trip.setPublic(isPublic);
        return toResponse(trip, TripRole.OWNER);
    }

    private TripResponse toResponse(Trip t, TripRole role) {
        return new TripResponse(
            t.getId(), t.getTitle(), t.getStartDate(), t.getEndDate(),
            t.getCreatedBy(), t.getCreatedAt(), role.name(),
            null, 0, 0, t.isPublic()
        );
    }

}
