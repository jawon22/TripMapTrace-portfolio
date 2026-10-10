package tripmaps.backend.media.api;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import tripmaps.backend.media.api.dto.CommentRequest;
import tripmaps.backend.media.api.dto.CommentResponse;
import tripmaps.backend.media.service.CommentService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/trips/{tripId}/media/{mediaId}/comments")
public class CommentController {

    private final CommentService commentService;

    public CommentController(CommentService commentService) {
        this.commentService = commentService;
    }

    private Long currentUserId(Authentication auth) {
        return (Long) auth.getPrincipal();
    }

    @GetMapping
    public List<CommentResponse> list(@PathVariable Long tripId,
                                      @PathVariable Long mediaId,
                                      Authentication auth) {
        return commentService.list(tripId, mediaId, currentUserId(auth));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CommentResponse create(@PathVariable Long tripId,
                                  @PathVariable Long mediaId,
                                  @Valid @RequestBody CommentRequest req,
                                  Authentication auth) {
        return commentService.create(tripId, mediaId, currentUserId(auth), req);
    }

    @PatchMapping("/{commentId}")
    public CommentResponse update(@PathVariable Long tripId,
                                  @PathVariable Long mediaId,
                                  @PathVariable Long commentId,
                                  @Valid @RequestBody CommentRequest req,
                                  Authentication auth) {
        return commentService.update(tripId, mediaId, commentId, currentUserId(auth), req);
    }

    @DeleteMapping("/{commentId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long tripId,
                       @PathVariable Long mediaId,
                       @PathVariable Long commentId,
                       Authentication auth) {
        commentService.delete(tripId, mediaId, commentId, currentUserId(auth));
    }
}
