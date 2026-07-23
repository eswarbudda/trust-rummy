package com.trustrummy.backend.notifications;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.trustrummy.backend.presence.PresenceService;
import com.trustrummy.backend.presence.UserSessionRegistry;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * MVP delivery: push {@code NOTIFICATION} (+ unread count) on {@code /ws/user}
 * when the recipient is online. Persist-only when offline.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class WebSocketNotificationDelivery implements NotificationDeliveryPort {

    private final PresenceService presenceService;
    private final UserSessionRegistry userSessionRegistry;
    private final NotificationRepository notificationRepository;
    private final ObjectMapper objectMapper;

    @Override
    public void deliver(NotificationView notification) {
        if (!presenceService.isOnline(notification.userId())) {
            log.debug("Skip WS deliver for offline userId={} type={}", notification.userId(), notification.type());
            return;
        }
        try {
            Map<String, Object> frame = new LinkedHashMap<>();
            frame.put("type", "NOTIFICATION");
            frame.put("notificationId", notification.id().toString());
            frame.put("notificationType", notification.type());
            frame.put("payload", notification.payload());
            frame.put("createdAt", notification.createdAt().toString());
            frame.put("status", notification.status().name());

            String json = objectMapper.writeValueAsString(frame);
            boolean sent = userSessionRegistry.publish(notification.userId(), json);
            if (sent) {
                long unread = notificationRepository.countByUserIdAndStatus(
                        notification.userId(), NotificationStatus.UNREAD);
                Map<String, Object> countFrame = Map.of(
                        "type", "NOTIFICATION_COUNT",
                        "unreadCount", unread
                );
                userSessionRegistry.publish(notification.userId(), objectMapper.writeValueAsString(countFrame));
            }
        } catch (Exception ex) {
            log.warn("Failed WS notification delivery userId={}: {}", notification.userId(), ex.toString());
        }
    }
}
