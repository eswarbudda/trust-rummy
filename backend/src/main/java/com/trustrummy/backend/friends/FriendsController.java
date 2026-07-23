package com.trustrummy.backend.friends;

import com.trustrummy.backend.entity.User;
import com.trustrummy.backend.repository.UserRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
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
@RequestMapping("/api/v1/friends")
@RequiredArgsConstructor
public class FriendsController {

    private final FriendsService friendsService;
    private final UserRepository userRepository;

    @GetMapping
    public Map<String, Object> listFriends(@AuthenticationPrincipal UserDetails principal) {
        Long userId = requireUserId(principal);
        List<FriendResponse> friends = friendsService.listFriends(userId);
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("friends", friends);
        body.put("count", friends.size());
        return body;
    }

    @GetMapping("/requests")
    public Map<String, List<FriendRequestResponse>> listRequests(@AuthenticationPrincipal UserDetails principal) {
        return friendsService.listRequests(requireUserId(principal));
    }

    @PostMapping("/requests")
    public FriendshipView createRequest(
            @AuthenticationPrincipal UserDetails principal,
            @Valid @RequestBody CreateFriendRequest body
    ) {
        Long userId = requireUserId(principal);
        if (body.userId() != null) {
            return friendsService.sendRequestByUserId(userId, body.userId());
        }
        return friendsService.sendRequestByUsername(userId, body.username());
    }

    @PostMapping("/requests/{id}/accept")
    public FriendshipView accept(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable("id") long id
    ) {
        return friendsService.accept(requireUserId(principal), id);
    }

    @PostMapping("/requests/{id}/decline")
    public FriendshipView decline(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable("id") long id
    ) {
        return friendsService.decline(requireUserId(principal), id);
    }

    @DeleteMapping("/{userId}")
    public FriendshipView unfriend(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable("userId") long otherUserId
    ) {
        return friendsService.unfriend(requireUserId(principal), otherUserId);
    }

    @PostMapping("/{userId}/block")
    public FriendshipView block(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable("userId") long otherUserId
    ) {
        return friendsService.block(requireUserId(principal), otherUserId);
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
