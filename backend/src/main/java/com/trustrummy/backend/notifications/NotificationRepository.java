package com.trustrummy.backend.notifications;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

public interface NotificationRepository extends JpaRepository<NotificationEntity, UUID> {

    Page<NotificationEntity> findByUserIdOrderByCreatedAtDesc(Long userId, Pageable pageable);

    Page<NotificationEntity> findByUserIdAndStatusOrderByCreatedAtDesc(
            Long userId, NotificationStatus status, Pageable pageable);

    long countByUserIdAndStatus(Long userId, NotificationStatus status);

    Optional<NotificationEntity> findByUserIdAndDedupeKey(Long userId, String dedupeKey);

    Optional<NotificationEntity> findByIdAndUserId(UUID id, Long userId);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update NotificationEntity n
               set n.status = :readStatus,
                   n.readAt = :readAt
             where n.userId = :userId
               and n.status = :unreadStatus
            """)
    int markAllRead(
            @Param("userId") Long userId,
            @Param("readAt") Instant readAt,
            @Param("readStatus") NotificationStatus readStatus,
            @Param("unreadStatus") NotificationStatus unreadStatus
    );
}
