package tripmaps.backend.invite.service;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import tripmaps.backend.fcm.FcmService;
import tripmaps.backend.invite.api.dto.InviteCreateResponse;
import tripmaps.backend.invite.api.dto.InviteInfoResponse;
import tripmaps.backend.invite.api.dto.InviteJoinResponse;
import tripmaps.backend.invite.api.dto.InviteStatusResponse;
import tripmaps.backend.invite.domain.InviteToken;
import tripmaps.backend.invite.repository.InviteTokenRepository;
import tripmaps.backend.trip.domain.TripMember;
import tripmaps.backend.trip.domain.TripRole;
import tripmaps.backend.trip.repository.TripMemberRepository;
import tripmaps.backend.trip.repository.TripRepository;
import tripmaps.backend.user.repository.UserRepository;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;

@Service
public class InviteService {

    private static final Logger log = LoggerFactory.getLogger(InviteService.class);

    private final InviteTokenRepository inviteTokenRepository;
    private final TripMemberRepository tripMemberRepository;
    private final TripRepository tripRepository;
    private final UserRepository userRepository;
    private final FcmService fcmService;

    public InviteService(InviteTokenRepository inviteTokenRepository,
                         TripMemberRepository tripMemberRepository,
                         TripRepository tripRepository,
                         UserRepository userRepository,
                         FcmService fcmService) {
        this.inviteTokenRepository = inviteTokenRepository;
        this.tripMemberRepository = tripMemberRepository;
        this.tripRepository = tripRepository;
        this.userRepository = userRepository;
        this.fcmService = fcmService;
    }

    // ── 초대 토큰 정보 조회 (인증 불필요) ──────────────────────────
    @Transactional(readOnly = true)
    public InviteInfoResponse getInviteInfo(String token) {
        InviteToken invite = inviteTokenRepository.findByToken(token)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "유효하지 않은 초대 링크입니다."));

        if (invite.isExpired(Instant.now())) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "만료된 초대 링크입니다.");
        }

        String tripTitle = tripRepository.findById(invite.getTripId())
                .map(t -> t.getTitle())
                .orElse("알 수 없는 여행");

        long memberCount = tripMemberRepository.countByTripId(invite.getTripId());

        // OWNER 찾기
        String ownerNickname = tripMemberRepository.findAllByTripIdOrderByIdAsc(invite.getTripId())
                .stream()
                .filter(m -> m.getRole() == TripRole.OWNER)
                .findFirst()
                .flatMap(m -> userRepository.findById(m.getUserId()))
                .map(u -> u.getNickname() != null ? u.getNickname() : u.getEmail())
                .orElse("알 수 없음");

        return new InviteInfoResponse(tripTitle, (int) memberCount, ownerNickname);
    }

    // ── 초대 상태 조회 ────────────────────────────────────────────
    @Transactional(readOnly = true)
    public InviteStatusResponse getInviteStatus(Long tripId, Long requesterUserId) {
        tripMemberRepository.findByTripIdAndUserId(tripId, requesterUserId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.FORBIDDEN, "해당 여행의 멤버가 아닙니다."));

        return inviteTokenRepository.findFirstByTripIdOrderByCreatedAtDesc(tripId)
                .map(invite -> {
                    boolean expired = invite.isExpired(Instant.now()) || !invite.canUse();
                    return new InviteStatusResponse(invite.getToken(), invite.getExpiresAt(), expired);
                })
                .orElse(new InviteStatusResponse(null, null, true));
    }

    // ── 초대 토큰 생성 (유효 토큰 존재 시 재사용) ─────────────────
    @Transactional
    public InviteCreateResponse createInvite(Long tripId, Long requesterUserId) {
        TripMember member = tripMemberRepository.findByTripIdAndUserId(tripId, requesterUserId)
                .orElseThrow(() -> new IllegalStateException("회원이 아닙니다."));
        if (member.getRole() != TripRole.OWNER) {
            throw new IllegalStateException("관리자만 초대 링크를 생성할 수 있습니다.");
        }

        // 유효한 기존 토큰이 있으면 재사용
        Instant now = Instant.now();
        return inviteTokenRepository.findFirstByTripIdOrderByCreatedAtDesc(tripId)
                .filter(existing -> !existing.isExpired(now) && existing.canUse())
                .map(existing -> new InviteCreateResponse(existing.getToken(), existing.getExpiresAt(), existing.getMaxUses()))
                .orElseGet(() -> {
                    String token = generateUniqueToken();
                    Instant expiresAt = now.plus(Duration.ofDays(7));
                    int maxUses = 10;
                    inviteTokenRepository.save(new InviteToken(tripId, token, expiresAt, maxUses));
                    return new InviteCreateResponse(token, expiresAt, maxUses);
                });
    }

    // ── 초대 토큰으로 참여 ────────────────────────────────────────
    @Transactional
    public InviteJoinResponse joinByToken(String token, Long userId) {
        InviteToken invite = inviteTokenRepository.findByToken(token)
                .orElseThrow(() -> new IllegalStateException("초대 토큰이 유효하지 않습니다."));

        Instant now = Instant.now();
        if (invite.isExpired(now)) {
            throw new IllegalStateException("초대 토큰이 만료되었습니다.");
        }
        if (!invite.canUse()) {
            throw new IllegalStateException("초대 토큰 사용량 초과");
        }

        boolean already = tripMemberRepository.existsByTripIdAndUserId(invite.getTripId(), userId);
        if (already) {
            throw new IllegalStateException("이미 참여 중인 여행입니다.");
        }

        tripMemberRepository.save(new TripMember(invite.getTripId(), userId, TripRole.VIEWER));
        invite.increaseUsedCount();

        // 참여 알림 (OWNER에게)
        try {
            fcmService.notifyJoin(invite.getTripId(), userId);
        } catch (Exception e) {
            log.warn("FCM 참여 알림 발송 실패: {}", e.getMessage());
        }

        return new InviteJoinResponse(invite.getTripId(), userId, TripRole.VIEWER.name());
    }

    private String generateUniqueToken() {
        SecureRandom random = new SecureRandom();
        for (int i = 0; i < 5; i++) {
            byte[] bytes = new byte[32];
            random.nextBytes(bytes);
            String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
            if (!inviteTokenRepository.existsByToken(token)) return token;
        }
        throw new IllegalStateException("고유한 토큰 생성 실패.");
    }
}
