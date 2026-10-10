package tripmaps.backend.invite.api;

import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import tripmaps.backend.invite.api.dto.InviteCreateResponse;
import tripmaps.backend.invite.api.dto.InviteInfoResponse;
import tripmaps.backend.invite.api.dto.InviteJoinResponse;
import tripmaps.backend.invite.api.dto.InviteStatusResponse;
import tripmaps.backend.invite.service.InviteService;

@RestController
@RequestMapping("/api/v1")
public class InviteController {

    private final InviteService inviteService;

    public InviteController(InviteService inviteService) {
        this.inviteService = inviteService;
    }

    private Long currentUserId(Authentication auth) {
        return (Long) auth.getPrincipal();
    }

    /** 딥링크 탭 시 여행 정보 미리보기 — 인증 불필요 */
    @GetMapping("/invite/{token}/info")
    public InviteInfoResponse getInviteInfo(@PathVariable String token) {
        return inviteService.getInviteInfo(token);
    }

    /** 현재 초대 토큰 상태 조회 */
    @GetMapping("/trips/{tripId}/invite/status")
    public InviteStatusResponse getInviteStatus(@PathVariable Long tripId, Authentication auth) {
        return inviteService.getInviteStatus(tripId, currentUserId(auth));
    }

    /** 초대 토큰 생성 (유효 토큰 존재 시 재사용) */
    @PostMapping("/trips/{tripId}/invites")
    public InviteCreateResponse createInvite(@PathVariable Long tripId, Authentication auth) {
        return inviteService.createInvite(tripId, currentUserId(auth));
    }

    /** 초대 토큰으로 여행 참여 */
    @PostMapping("/invites/{token}/join")
    public InviteJoinResponse join(@PathVariable String token, Authentication auth) {
        return inviteService.joinByToken(token, currentUserId(auth));
    }
}
