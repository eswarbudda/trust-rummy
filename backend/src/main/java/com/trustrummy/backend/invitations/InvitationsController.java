package com.trustrummy.backend.invitations;

import com.trustrummy.backend.entity.User;
import com.trustrummy.backend.repository.UserRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequiredArgsConstructor
public class InvitationsController {

    private final InvitationsService invitationsService;
    private final UserRepository userRepository;

    @GetMapping("/api/v1/invitations/pending")
    public Map<String, Object> listPending(@AuthenticationPrincipal UserDetails principal) {
        List<InvitationResponse> items = invitationsService.listPendingForUser(requireUserId(principal));
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("items", items);
        body.put("count", items.size());
        return body;
    }

    @PostMapping("/api/v1/invitations/{id}/accept")
    public InvitationResponse accept(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable("id") UUID id
    ) {
        return invitationsService.accept(requireUserId(principal), id);
    }

    @PostMapping("/api/v1/invitations/{id}/decline")
    public InvitationResponse decline(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable("id") UUID id
    ) {
        return invitationsService.decline(requireUserId(principal), id);
    }

    @GetMapping("/api/v1/rooms/{roomCode}/invitations")
    public Map<String, List<InvitationResponse>> listForRoom(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable("roomCode") String roomCode
    ) {
        return invitationsService.listForRoom(requireUserId(principal), roomCode);
    }

    @PostMapping("/api/v1/rooms/{roomCode}/invitations")
    public InvitationResponse inviteToRoom(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable("roomCode") String roomCode,
            @Valid @RequestBody CreateRoomInvitationRequest body
    ) {
        return invitationsService.inviteToRoom(requireUserId(principal), roomCode, body.userId());
    }

    private Long requireUserId(UserDetails principal) {
        if (principal == null || principal.getUsername() == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unauthorized");
        }
        return userRepository.findByUsername(principal.getUsername())
                .map(User::getId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unauthorized"));
    }
}
