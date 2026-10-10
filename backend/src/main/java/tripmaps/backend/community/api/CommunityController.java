package tripmaps.backend.community.api;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import tripmaps.backend.community.api.dto.*;
import tripmaps.backend.community.service.CommunityService;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/community")
public class CommunityController {

    private final CommunityService communityService;

    public CommunityController(CommunityService communityService) {
        this.communityService = communityService;
    }

    @GetMapping("/trips")
    public CommunityPageResponse<CommunityTripSummary> listTrips(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "latest") String sort,
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "false") boolean onlyLiked,
            Authentication auth) {
        return communityService.listPublicTrips(page, size, sort, keyword, onlyLiked, currentUserId(auth));
    }

    @GetMapping("/trips/{tripId}")
    public CommunityTripDetail getTripDetail(@PathVariable Long tripId, Authentication auth) {
        return communityService.getTripDetail(tripId, currentUserId(auth));
    }

    @PostMapping("/trips/{tripId}/like")
    public Map<String, Boolean> toggleLike(@PathVariable Long tripId, Authentication auth) {
        boolean isLiked = communityService.toggleLike(tripId, currentUserId(auth));
        return Map.of("isLiked", isLiked);
    }

    @GetMapping("/trips/{tripId}/comments")
    public List<CommunityCommentResponse> getComments(@PathVariable Long tripId, Authentication auth) {
        return communityService.getComments(tripId, currentUserId(auth));
    }

    @PostMapping("/trips/{tripId}/comments")
    @ResponseStatus(HttpStatus.CREATED)
    public CommunityCommentResponse addComment(
            @PathVariable Long tripId,
            @RequestBody TripCommentRequest req,
            Authentication auth) {
        return communityService.addComment(tripId, req.content(), currentUserId(auth));
    }

    @PatchMapping("/trips/{tripId}/comments/{commentId}")
    public CommunityCommentResponse updateComment(
            @PathVariable Long tripId,
            @PathVariable Long commentId,
            @RequestBody TripCommentRequest req,
            Authentication auth) {
        return communityService.updateComment(tripId, commentId, req.content(), currentUserId(auth));
    }

    @DeleteMapping("/trips/{tripId}/comments/{commentId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteComment(
            @PathVariable Long tripId,
            @PathVariable Long commentId,
            Authentication auth) {
        communityService.deleteComment(tripId, commentId, currentUserId(auth));
    }

    private Long currentUserId(Authentication auth) {
        if (auth == null) return null;
        return (Long) auth.getPrincipal();
    }
}
