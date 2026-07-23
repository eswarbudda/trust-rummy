package com.trustrummy.backend.recentplayers;

import com.trustrummy.backend.entity.User;
import com.trustrummy.backend.friends.FriendshipView;
import com.trustrummy.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/recent-players")
@RequiredArgsConstructor
public class RecentPlayersController {

    private final RecentPlayersService recentPlayersService;
    private final UserRepository userRepository;

    @GetMapping
    public Map<String, Object> list(
            @AuthenticationPrincipal UserDetails principal,
            @RequestParam(value = "limit", defaultValue = "30") int limit
    ) {
        Long userId = requireUserId(principal);
        List<RecentOpponentResponse> opponents = recentPlayersService.listRecent(userId, limit);
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("opponents", opponents);
        body.put("count", opponents.size());
        return body;
    }

    @PostMapping("/{userId}/friend-request")
    public FriendshipView friendRequest(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable("userId") long opponentUserId
    ) {
        return recentPlayersService.sendFriendRequest(requireUserId(principal), opponentUserId);
    }

    @PostMapping("/{userId}/invite-again")
    public void inviteAgain(@PathVariable("userId") long ignored) {
        throw new ResponseStatusException(HttpStatus.NOT_IMPLEMENTED, "Invitations module not available yet");
    }

    @GetMapping("/{userId}/profile")
    public void profile(@PathVariable("userId") long ignored) {
        throw new ResponseStatusException(HttpStatus.NOT_IMPLEMENTED, "Player profiles not available yet");
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
