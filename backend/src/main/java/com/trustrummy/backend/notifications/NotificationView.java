package com.trustrummy.backend.notifications;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

public record NotificationView(
        UUID id,
        Long userId,
        String type,
        Map<String, Object> payload,
        NotificationStatus status,
        Instant createdAt,
        Instant readAt,
        String dedupeKey
) {
    static NotificationView from(NotificationEntity entity) {
        return new NotificationView(
                entity.getId(),
                entity.getUserId(),
                entity.getType(),
                entity.getPayload() == null ? Map.of() : Map.copyOf(entity.getPayload()),
                entity.getStatus(),
                entity.getCreatedAt(),
                entity.getReadAt(),
                entity.getDedupeKey()
        );
    }
}
