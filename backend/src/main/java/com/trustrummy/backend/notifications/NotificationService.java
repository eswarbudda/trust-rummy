package com.trustrummy.backend.notifications;

import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.springframework.http.HttpStatus.BAD_REQUEST;

@Service
@RequiredArgsConstructor
public class NotificationService implements NotificationPort {

    private final NotificationRepository notificationRepository;
    private final NotificationDeliveryPort deliveryPort;

    @Override
    @Transactional
    public NotificationView create(long userId, String type, Map<String, Object> payload, String dedupeKey) {
        if (type == null || type.isBlank()) {
            throw new ResponseStatusException(BAD_REQUEST, "Notification type is required");
        }
        String normalizedDedupe = (dedupeKey == null || dedupeKey.isBlank()) ? null : dedupeKey.trim();
        if (normalizedDedupe != null) {
            Optional<NotificationEntity> existing =
                    notificationRepository.findByUserIdAndDedupeKey(userId, normalizedDedupe);
            if (existing.isPresent()) {
                return NotificationView.from(existing.get());
            }
        }

        NotificationEntity entity = NotificationEntity.builder()
                .userId(userId)
                .type(type.trim())
                .payload(payload == null ? new HashMap<>() : new HashMap<>(payload))
                .status(NotificationStatus.UNREAD)
                .dedupeKey(normalizedDedupe)
                .build();
        NotificationEntity saved = notificationRepository.save(entity);
        NotificationView view = NotificationView.from(saved);
        deliveryPort.deliver(view);
        return view;
    }

    @Override
    @Transactional
    public Optional<NotificationView> markRead(long userId, UUID notificationId) {
        Optional<NotificationEntity> found = notificationRepository.findByIdAndUserId(notificationId, userId);
        if (found.isEmpty()) {
            return Optional.empty();
        }
        NotificationEntity entity = found.get();
        if (entity.getStatus() == NotificationStatus.UNREAD) {
            entity.setStatus(NotificationStatus.READ);
            entity.setReadAt(Instant.now());
            notificationRepository.save(entity);
        }
        return Optional.of(NotificationView.from(entity));
    }

    @Override
    @Transactional
    public int markAllRead(long userId) {
        return notificationRepository.markAllRead(userId, Instant.now());
    }

    @Override
    @Transactional(readOnly = true)
    public List<NotificationView> list(long userId, NotificationStatus status, int page, int size) {
        int safePage = Math.max(page, 0);
        int safeSize = Math.min(Math.max(size, 1), 50);
        var pageable = PageRequest.of(safePage, safeSize);
        var result = status == null
                ? notificationRepository.findByUserIdOrderByCreatedAtDesc(userId, pageable)
                : notificationRepository.findByUserIdAndStatusOrderByCreatedAtDesc(userId, status, pageable);
        return result.stream().map(NotificationView::from).toList();
    }

    @Override
    @Transactional(readOnly = true)
    public int countUnread(long userId) {
        return (int) notificationRepository.countByUserIdAndStatus(userId, NotificationStatus.UNREAD);
    }
}
