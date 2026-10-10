package tripmaps.backend.invitation.service;

import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import tripmaps.backend.fcm.FcmService;
import tripmaps.backend.invitation.api.dto.ReceivedInvitationResponse;
import tripmaps.backend.invitation.api.dto.UserSearchResponse;
import tripmaps.backend.invitation.domain.InvitationStatus;
import tripmaps.backend.invitation.domain.TripInvitation;
import tripmaps.backend.invitation.repository.TripInvitationRepository;
import tripmaps.backend.trip.domain.TripMember;
import tripmaps.backend.trip.domain.TripRole;
import tripmaps.backend.trip.repository.TripMemberRepository;
import tripmaps.backend.trip.repository.TripRepository;
import tripmaps.backend.user.domain.User;
import tripmaps.backend.user.repository.UserRepository;

import java.util.List;

@Service
public class InvitationService {

    private final TripInvitationRepository invitationRepository;
    private final TripMemberRepository tripMemberRepository;
    private final TripRepository tripRepository;
    private final UserRepository userRepository;
    private final FcmService fcmService;

    public InvitationService(TripInvitationRepository invitationRepository,
                             TripMemberRepository tripMemberRepository,
                             TripRepository tripRepository,
                             UserRepository userRepository,
                             FcmService fcmService) {
        this.invitationRepository = invitationRepository;
        this.tripMemberRepository = tripMemberRepository;
        this.tripRepository = tripRepository;
        this.userRepository = userRepository;
        this.fcmService = fcmService;
    }

    // ── 사용자 검색 (닉네임 부분일치 또는 이메일 정확일치, 본인 제외) ──────────
    @Transactional(readOnly = true)
    public List<UserSearchResponse> searchUsers(String q, Long selfId) {
        if (q == null || q.trim().isEmpty()) return List.of();
        return userRepository.searchByNicknameOrEmail(q.trim(), selfId, PageRequest.of(0, 20))
                .stream()
                .map(u -> new UserSearchResponse(
                        u.getId(),
                        u.getNickname(),
                        u.getEmail(),
                        u.getProfileImageUrl()))
                .toList();
    }

    // ── 초대 요청 발송 (OWNER만) ───────────────────────────────────────────
    @Transactional
    public void invite(Long tripId, Long inviterUserId, Long inviteeUserId) {
        TripMember inviter = tripMemberRepository.findByTripIdAndUserId(tripId, inviterUserId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.FORBIDDEN, "해당 여행의 멤버가 아닙니다."));
        if (inviter.getRole() != TripRole.OWNER) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "관리자만 초대할 수 있습니다.");
        }
        if (inviteeUserId == null || inviteeUserId.equals(inviterUserId)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "잘못된 초대 대상입니다.");
        }
        userRepository.findById(inviteeUserId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "사용자를 찾을 수 없습니다."));
        if (tripMemberRepository.existsByTripIdAndUserId(tripId, inviteeUserId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "이미 여행 멤버입니다.");
        }
        if (invitationRepository.existsByTripIdAndInviteeUserIdAndStatus(
                tripId, inviteeUserId, InvitationStatus.PENDING)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "이미 초대한 사용자입니다.");
        }

        invitationRepository.save(new TripInvitation(tripId, inviterUserId, inviteeUserId, TripRole.VIEWER));
        fcmService.notifyInvitation(tripId, inviteeUserId, inviterUserId);
    }

    // ── 내가 받은 대기중 초대 목록 ─────────────────────────────────────────
    @Transactional(readOnly = true)
    public List<ReceivedInvitationResponse> myInvitations(Long userId) {
        return invitationRepository.findAllByInviteeUserIdAndStatusOrderByIdDesc(userId, InvitationStatus.PENDING)
                .stream()
                .map(inv -> {
                    String tripTitle = tripRepository.findById(inv.getTripId())
                            .map(t -> t.getTitle())
                            .orElse("알 수 없는 여행");
                    String inviterNickname = userRepository.findById(inv.getInviterUserId())
                            .map(u -> u.getNickname() != null ? u.getNickname() : u.getEmail())
                            .orElse("알 수 없음");
                    int memberCount = (int) tripMemberRepository.countByTripId(inv.getTripId());
                    return new ReceivedInvitationResponse(
                            inv.getId(), inv.getTripId(), tripTitle, inviterNickname, memberCount);
                })
                .toList();
    }

    // ── 초대 수락 → 멤버 추가 ──────────────────────────────────────────────
    @Transactional
    public Long accept(Long invitationId, Long userId) {
        TripInvitation inv = invitationRepository.findById(invitationId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "초대를 찾을 수 없습니다."));
        if (!inv.getInviteeUserId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "본인에게 온 초대가 아닙니다.");
        }
        if (inv.getStatus() != InvitationStatus.PENDING) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "이미 처리된 초대입니다.");
        }

        inv.accept();
        if (!tripMemberRepository.existsByTripIdAndUserId(inv.getTripId(), userId)) {
            tripMemberRepository.save(new TripMember(inv.getTripId(), userId, inv.getRole()));
        }
        fcmService.notifyJoin(inv.getTripId(), userId); // OWNER에게 참여 알림
        return inv.getTripId();
    }

    // ── 초대 거절 ──────────────────────────────────────────────────────────
    @Transactional
    public void decline(Long invitationId, Long userId) {
        TripInvitation inv = invitationRepository.findById(invitationId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "초대를 찾을 수 없습니다."));
        if (!inv.getInviteeUserId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "본인에게 온 초대가 아닙니다.");
        }
        if (inv.getStatus() != InvitationStatus.PENDING) return;
        inv.decline();
    }
}
