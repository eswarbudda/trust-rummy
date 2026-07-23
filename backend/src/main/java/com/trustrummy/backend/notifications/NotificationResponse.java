package com.trustrummy.backend.notifications;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

public record NotificationResponse(
        UUID id,
        String type,
        Map<String, Object> payload,
        String status,
        Instant createdAt,
        Instant readAt
) {
    static NotificationResponse from(NotificationView view) {
        return new NotificationResponse(
                view.id(),
                view.type(),
                view.payload(),
                view.status().name(),
                view.createdAt(),
                view.readAt()
        );
    }
}
