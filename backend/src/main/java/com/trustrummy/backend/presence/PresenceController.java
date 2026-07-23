package com.trustrummy.backend.presence;

import com.trustrummy.backend.entity.User;
import com.trustrummy.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Read-only presence queries for clients and manual verification.
 * Online state comes solely from {@link PresenceService} (active {@code /ws/user} sessions).
 */
@RestController
@RequestMapping("/api/v1/presence")
@RequiredArgsConstructor
public class PresenceController {

    private final PresenceService presenceService;
    private final UserRepository userRepository;

    @GetMapping("/me")
    public Map<String, Object> me(@AuthenticationPrincipal UserDetails principal) {
        Long userId = requireUserId(principal);
        return Map.of(
                "userId", userId,
                "status", presenceService.getStatus(userId).name(),
                "sessionCount", presenceService.sessionCount(userId)
        );
    }

    /**
     * Batch online check. Used later by Friends; available now for verification.
     * Query: {@code ?userIds=1&userIds=2} or {@code ?userIds=1,2}.
     */
    @GetMapping
    public Map<String, Object> status(
            @AuthenticationPrincipal UserDetails principal,
            @RequestParam(value = "userIds", required = false) List<String> userIds
    ) {
        requireUserId(principal);
        List<Long> ids = parseUserIds(userIds);
        var online = presenceService.filterOnline(ids);
        List<Map<String, Object>> results = new ArrayList<>();
        for (Long id : ids) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("userId", id);
            row.put("status", online.contains(id) ? PresenceStatus.ONLINE.name() : PresenceStatus.OFFLINE.name());
            results.add(row);
        }
        return Map.of("results", results);
    }

    private Long requireUserId(UserDetails principal) {
        if (principal == null || principal.getUsername() == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unauthorized");
        }
        return userRepository.findByUsername(principal.getUsername())
                .map(User::getId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unauthorized"));
    }

    private List<Long> parseUserIds(List<String> raw) {
        if (raw == null || raw.isEmpty()) {
            return List.of();
        }
        List<Long> ids = new ArrayList<>();
        for (String part : raw) {
            if (part == null || part.isBlank()) {
                continue;
            }
            for (String token : part.split(",")) {
                String t = token.trim();
                if (t.isEmpty()) {
                    continue;
                }
                try {
                    ids.add(Long.parseLong(t));
                } catch (NumberFormatException ignored) {
                    // skip malformed ids
                }
            }
        }
        return ids;
    }
}
