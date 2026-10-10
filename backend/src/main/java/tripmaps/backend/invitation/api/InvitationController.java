package tripmaps.backend.invitation.api;

import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import tripmaps.backend.invitation.api.dto.InvitationActionResponse;
import tripmaps.backend.invitation.api.dto.ReceivedInvitationResponse;
import tripmaps.backend.invitation.api.dto.SendInvitationRequest;
import tripmaps.backend.invitation.api.dto.UserSearchResponse;
import tripmaps.backend.invitation.service.InvitationService;

import java.util.List;

@RestController
@RequestMapping("/api/v1")
public class InvitationController {

    private final InvitationService invitationService;

    public InvitationController(InvitationService invitationService) {
        this.invitationService = invitationService;
    }

    private Long currentUserId(Authentication auth) {
        return (Long) auth.getPrincipal();
    }

    /** 닉네임/이메일로 사용자 검색 */
    @GetMapping("/users/search")
    public List<UserSearchResponse> search(@RequestParam("q") String q, Authentication auth) {
        return invitationService.searchUsers(q, currentUserId(auth));
    }

    /** 특정 사용자에게 초대 요청 발송 (OWNER만) */
    @PostMapping("/trips/{tripId}/invitations")
    public void invite(@PathVariable Long tripId,
                       @RequestBody SendInvitationRequest req,
                       Authentication auth) {
        invitationService.invite(tripId, currentUserId(auth), req.inviteeUserId());
    }

    /** 내가 받은 대기중 초대 목록 */
    @GetMapping("/me/invitations")
    public List<ReceivedInvitationResponse> myInvitations(Authentication auth) {
        return invitationService.myInvitations(currentUserId(auth));
    }

    /** 초대 수락 */
    @PostMapping("/invitations/{id}/accept")
    public InvitationActionResponse accept(@PathVariable Long id, Authentication auth) {
        return new InvitationActionResponse(invitationService.accept(id, currentUserId(auth)));
    }

    /** 초대 거절 */
    @PostMapping("/invitations/{id}/decline")
    public void decline(@PathVariable Long id, Authentication auth) {
        invitationService.decline(id, currentUserId(auth));
    }
}
