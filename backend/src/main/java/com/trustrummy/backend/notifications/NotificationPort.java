package com.trustrummy.backend.notifications;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Port used by Friends, Invitations, and other producers.
 * Implementations persist first, then attempt realtime delivery.
 */
public interface NotificationPort {

    NotificationView create(long userId, String type, Map<String, Object> payload, String dedupeKey);

    default NotificationView create(long userId, String type, Map<String, Object> payload) {
        return create(userId, type, payload, null);
    }

    Optional<NotificationView> markRead(long userId, UUID notificationId);

    int markAllRead(long userId);

    List<NotificationView> list(long userId, NotificationStatus status, int page, int size);

    int countUnread(long userId);
}
