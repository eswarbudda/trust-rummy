package com.trustrummy.backend.notifications;

import com.trustrummy.backend.entity.User;
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
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationPort notificationPort;
    private final UserRepository userRepository;

    @GetMapping
    public Map<String, Object> list(
            @AuthenticationPrincipal UserDetails principal,
            @RequestParam(value = "status", required = false) String status,
            @RequestParam(value = "page", defaultValue = "0") int page,
            @RequestParam(value = "size", defaultValue = "20") int size
    ) {
        Long userId = requireUserId(principal);
        NotificationStatus parsed = parseStatus(status);
        List<NotificationResponse> items = notificationPort.list(userId, parsed, page, size).stream()
                .map(NotificationResponse::from)
                .toList();
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("items", items);
        body.put("page", page);
        body.put("size", size);
        body.put("unreadCount", notificationPort.countUnread(userId));
        return body;
    }

    @GetMapping("/unread-count")
    public Map<String, Object> unreadCount(@AuthenticationPrincipal UserDetails principal) {
        Long userId = requireUserId(principal);
        return Map.of("unreadCount", notificationPort.countUnread(userId));
    }

    @PostMapping("/{id}/read")
    public NotificationResponse markRead(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable("id") UUID id
    ) {
        Long userId = requireUserId(principal);
        return notificationPort.markRead(userId, id)
                .map(NotificationResponse::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Notification not found"));
    }

    @PostMapping("/read-all")
    public Map<String, Object> markAllRead(@AuthenticationPrincipal UserDetails principal) {
        Long userId = requireUserId(principal);
        int updated = notificationPort.markAllRead(userId);
        return Map.of(
                "updated", updated,
                "unreadCount", notificationPort.countUnread(userId)
        );
    }

    /**
     * Dev/manual verification helper — creates a sample ROOM_INVITATION for the caller.
     * Friends/Invitations modules will call {@link NotificationPort} directly instead.
     */
    @PostMapping("/dev/sample")
    public NotificationResponse createSample(@AuthenticationPrincipal UserDetails principal) {
        Long userId = requireUserId(principal);
        NotificationView view = notificationPort.create(
                userId,
                NotificationTypes.ROOM_INVITATION,
                Map.of(
                        "roomCode", "SAMPLE",
                        "fromUsername", "system",
                        "variant", "POINTS",
                        "stake", 0
                ),
                "sample:" + userId + ":" + System.currentTimeMillis()
        );
        return NotificationResponse.from(view);
    }

    private Long requireUserId(UserDetails principal) {
        if (principal == null || principal.getUsername() == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unauthorized");
        }
        return userRepository.findByUsername(principal.getUsername())
                .map(User::getId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unauthorized"));
    }

    private NotificationStatus parseStatus(String status) {
        if (status == null || status.isBlank()) {
            return null;
        }
        try {
            return NotificationStatus.valueOf(status.trim().toUpperCase());
        } catch (IllegalArgumentException ex) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid status: " + status);
        }
    }
}
