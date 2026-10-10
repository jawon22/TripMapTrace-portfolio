package tripmaps.backend.user.api;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import tripmaps.backend.media.api.dto.MediaResponse;
import tripmaps.backend.media.service.MediaService;
import tripmaps.backend.user.api.dto.*;
import tripmaps.backend.user.service.UserService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;
    private final MediaService mediaService;

    public UserController(UserService userService, MediaService mediaService) {
        this.userService = userService;
        this.mediaService = mediaService;
    }

    private Long currentUserId(Authentication auth) {
        return (Long) auth.getPrincipal();
    }

    @GetMapping("/me")
    public UserResponse getMe(Authentication auth) {
        return userService.getMe(currentUserId(auth));
    }

    @GetMapping("/me/stats")
    public UserStatsResponse getStats(Authentication auth) {
        return userService.getStats(currentUserId(auth));
    }

    @PostMapping("/me/avatar/presign")
    public AvatarPresignResponse presignAvatar(Authentication auth,
                                               @RequestBody AvatarPresignRequest req) {
        return userService.presignAvatar(currentUserId(auth), req);
    }

    @PatchMapping("/me/avatar/complete")
    public UserResponse completeAvatar(Authentication auth,
                                       @RequestBody AvatarCompleteRequest req) {
        return userService.completeAvatar(currentUserId(auth), req);
    }

    @PatchMapping("/me/password")
    public ResponseEntity<Void> changePassword(Authentication auth,
                                               @Valid @RequestBody PasswordChangeRequest req) {
        userService.changePassword(currentUserId(auth), req);
        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/me/nickname")
    public UserResponse updateNickname(Authentication auth,
                                       @RequestBody NicknameUpdateRequest req) {
        return userService.updateNickname(currentUserId(auth), req);
    }

    @PatchMapping("/me/fcm-token")
    public void updateFcmToken(Authentication auth,
                               @RequestBody FcmTokenRequest req) {
        userService.updateFcmToken(currentUserId(auth), req);
    }

    @GetMapping("/me/notification-settings")
    public NotificationSettingsResponse getNotificationSettings(Authentication auth) {
        return userService.getNotificationSettings(currentUserId(auth));
    }

    @PatchMapping("/me/notification-settings")
    public NotificationSettingsResponse updateNotificationSettings(Authentication auth,
                                                                   @RequestBody NotificationSettingsRequest req) {
        return userService.updateNotificationSettings(currentUserId(auth), req);
    }

    @GetMapping("/me/owner-trips")
    public List<OwnerTripResponse> getOwnerTrips(Authentication auth) {
        return userService.getOwnerTrips(currentUserId(auth));
    }

    @GetMapping("/me/media")
    public List<MediaResponse> getMyMedia(Authentication auth) {
        return mediaService.listMyMedia(currentUserId(auth));
    }

    @PatchMapping("/me/onboarding")
    public ResponseEntity<Void> completeOnboarding(Authentication auth) {
        userService.completeOnboarding(currentUserId(auth));
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/me")
    public ResponseEntity<Void> deleteAccount(Authentication auth) {
        userService.deleteAccount(currentUserId(auth));
        return ResponseEntity.noContent().build();
    }
}
