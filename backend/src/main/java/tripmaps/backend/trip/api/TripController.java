package tripmaps.backend.trip.api;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import tripmaps.backend.trip.api.dto.RoleChangeRequest;
import tripmaps.backend.trip.api.dto.SetCoverRequest;
import tripmaps.backend.trip.api.dto.TripCreateRequest;
import tripmaps.backend.trip.api.dto.TripMapPinResponse;
import tripmaps.backend.trip.api.dto.TripMemberResponse;
import tripmaps.backend.trip.api.dto.TripResponse;
import tripmaps.backend.trip.api.dto.TripStatsResponse;
import tripmaps.backend.trip.api.dto.TripUpdateRequest;
import tripmaps.backend.trip.api.dto.VisibilityRequest;
import tripmaps.backend.trip.service.TripService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/trips")
public class TripController {

    private final TripService tripService;

    public TripController(TripService tripService) {
        this.tripService = tripService;
    }

    private Long currentUserId(Authentication auth) {
        return (Long) auth.getPrincipal();
    }

    @PostMapping
    public TripResponse create(@Valid @RequestBody TripCreateRequest req, Authentication auth) {
        return tripService.createTrip(req, currentUserId(auth));
    }

    @GetMapping
    public List<TripResponse> listMine(Authentication auth) {
        return tripService.listMyTrips(currentUserId(auth));
    }

    @GetMapping("/map-pins")
    public List<TripMapPinResponse> mapPins(Authentication auth) {
        return tripService.getMapPins(currentUserId(auth));
    }

    @PatchMapping("/{tripId}")
    public TripResponse update(@PathVariable Long tripId,
                               @Valid @RequestBody TripUpdateRequest req,
                               Authentication auth) {
        return tripService.updateTrip(tripId, req, currentUserId(auth));
    }

    @DeleteMapping("/{tripId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long tripId, Authentication auth) {
        tripService.deleteTrip(tripId, currentUserId(auth));
    }

    @GetMapping("/{tripId}/members")
    public List<TripMemberResponse> members(@PathVariable Long tripId, Authentication auth) {
        return tripService.listMembers(tripId, currentUserId(auth));
    }

    @PatchMapping("/{tripId}/members/{memberId}/role")
    public void changeMemberRole(@PathVariable Long tripId,
                                 @PathVariable Long memberId,
                                 @Valid @RequestBody RoleChangeRequest req,
                                 Authentication auth) {
        tripService.changeMemberRole(tripId, memberId, req.role(), currentUserId(auth));
    }

    @DeleteMapping("/{tripId}/members/{memberId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeMember(@PathVariable Long tripId,
                             @PathVariable Long memberId,
                             Authentication auth) {
        tripService.removeMember(tripId, memberId, currentUserId(auth));
    }

    @DeleteMapping("/{tripId}/members/me")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void leaveTrip(@PathVariable Long tripId, Authentication auth) {
        tripService.leaveTrip(tripId, currentUserId(auth));
    }

    @GetMapping("/{tripId}/stats")
    public TripStatsResponse getStats(@PathVariable Long tripId, Authentication auth) {
        return tripService.getTripStats(tripId, currentUserId(auth));
    }

    @PatchMapping("/{tripId}/cover")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void setCover(@PathVariable Long tripId,
                         @RequestBody SetCoverRequest req,
                         Authentication auth) {
        tripService.setCover(tripId, req.mediaId(), currentUserId(auth));
    }

    @PatchMapping("/{tripId}/visibility")
    public TripResponse setVisibility(@PathVariable Long tripId,
                                      @RequestBody VisibilityRequest req,
                                      Authentication auth) {
        return tripService.setVisibility(tripId, req.isPublic(), currentUserId(auth));
    }
}
