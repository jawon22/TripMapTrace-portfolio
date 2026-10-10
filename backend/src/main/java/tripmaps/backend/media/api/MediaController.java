package tripmaps.backend.media.api;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import tripmaps.backend.media.api.dto.*;
import tripmaps.backend.media.service.MediaService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/trips/{tripId}/media")
public class MediaController {

    private final MediaService mediaService;

    public MediaController(MediaService mediaService) {
        this.mediaService = mediaService;
    }

    private Long currentUserId(Authentication auth) {
        return (Long) auth.getPrincipal();
    }

    @PostMapping("/presign")
    public MediaPresignResponse presign(@PathVariable Long tripId,
                                        @Valid @RequestBody MediaPresignRequest req,
                                        Authentication auth) {
        return mediaService.presignUpload(tripId, currentUserId(auth), req);
    }

    @PostMapping("/complete")
    public MediaResponse complete(@PathVariable Long tripId,
                                  @Valid @RequestBody MediaCompleteRequest req,
                                  Authentication auth) {
        return mediaService.complete(tripId, currentUserId(auth), req);
    }

    @GetMapping
    public List<MediaResponse> list(@PathVariable Long tripId, Authentication auth) {
        return mediaService.list(tripId, currentUserId(auth));
    }

    @GetMapping("/download-url/{mediaId}")
    public MediaDownloadUrlResponse downloadUrl(@PathVariable Long tripId,
                                                @PathVariable Long mediaId,
                                                Authentication auth) {
        return mediaService.getDownloadUrl(mediaId, currentUserId(auth));
    }

    @DeleteMapping("/{mediaId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteMedia(@PathVariable Long tripId,
                            @PathVariable Long mediaId,
                            Authentication auth) {
        mediaService.deleteMedia(tripId, mediaId, currentUserId(auth));
    }

    @PatchMapping("/{mediaId}/location")
    public MediaResponse updateLocation(@PathVariable Long tripId,
                                        @PathVariable Long mediaId,
                                        @Valid @RequestBody MediaLocationRequest req,
                                        Authentication auth) {
        return mediaService.updateLocation(tripId, mediaId, currentUserId(auth), req.lat(), req.lng());
    }

    @PostMapping("/{mediaId}/like")
    public MediaResponse toggleLike(@PathVariable Long tripId,
                                    @PathVariable Long mediaId,
                                    Authentication auth) {
        return mediaService.toggleLike(tripId, mediaId, currentUserId(auth));
    }
}
