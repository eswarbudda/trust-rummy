package com.trustrummy.backend.playgroups;

import com.trustrummy.backend.entity.User;
import com.trustrummy.backend.repository.UserRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/play-groups")
@RequiredArgsConstructor
public class PlayGroupsController {

    private final PlayGroupsService playGroupsService;
    private final UserRepository userRepository;

    @GetMapping
    public Map<String, Object> list(@AuthenticationPrincipal UserDetails principal) {
        Long userId = requireUserId(principal);
        List<PlayGroupResponse> items = playGroupsService.listMyGroups(userId);
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("items", items);
        body.put("count", items.size());
        return body;
    }

    @PostMapping
    public PlayGroupResponse create(
            @AuthenticationPrincipal UserDetails principal,
            @Valid @RequestBody CreatePlayGroupRequest body
    ) {
        return playGroupsService.create(requireUserId(principal), body.name(), body.maxMembers());
    }

    @GetMapping("/{id}")
    public PlayGroupResponse get(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable("id") long id
    ) {
        return playGroupsService.getGroup(requireUserId(principal), id);
    }

    @PatchMapping("/{id}")
    public PlayGroupResponse rename(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable("id") long id,
            @Valid @RequestBody RenamePlayGroupRequest body
    ) {
        return playGroupsService.rename(requireUserId(principal), id, body.name());
    }

    @DeleteMapping("/{id}")
    public PlayGroupResponse delete(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable("id") long id
    ) {
        return playGroupsService.softDelete(requireUserId(principal), id);
    }

    @PostMapping("/{id}/members")
    public PlayGroupResponse addMember(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable("id") long id,
            @Valid @RequestBody AddPlayGroupMemberRequest body
    ) {
        return playGroupsService.addMember(requireUserId(principal), id, body.userId(), body.username());
    }

    @PostMapping("/{id}/members/accept")
    public PlayGroupResponse acceptMemberInvite(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable("id") long id
    ) {
        return playGroupsService.acceptMemberInvite(requireUserId(principal), id);
    }

    @PostMapping("/{id}/members/decline")
    public PlayGroupResponse declineMemberInvite(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable("id") long id
    ) {
        return playGroupsService.declineMemberInvite(requireUserId(principal), id);
    }

    @DeleteMapping("/{id}/members/{userId}")
    public PlayGroupResponse removeMember(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable("id") long id,
            @PathVariable("userId") long memberUserId
    ) {
        return playGroupsService.removeMember(requireUserId(principal), id, memberUserId);
    }

    @PostMapping("/{id}/games")
    public StartPlayGroupGameResponse startGame(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable("id") long id,
            @Valid @RequestBody StartPlayGroupGameRequest body
    ) {
        return playGroupsService.startGame(
                requireUserId(principal),
                id,
                body.name(),
                body.stakeAmount(),
                body.gameType(),
                body.gameVariant(),
                body.dealsPerMatch()
        );
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
