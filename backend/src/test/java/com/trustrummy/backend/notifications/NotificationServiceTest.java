package com.trustrummy.backend.notifications;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class NotificationServiceTest {

    @Mock
    private NotificationRepository repository;
    @Mock
    private NotificationDeliveryPort deliveryPort;

    private NotificationService service;

    @BeforeEach
    void setUp() {
        service = new NotificationService(repository, deliveryPort);
    }

    @Test
    void createPersistsAndDelivers() {
        when(repository.save(any())).thenAnswer(inv -> {
            NotificationEntity e = inv.getArgument(0);
            if (e.getId() == null) {
                e.setId(UUID.randomUUID());
            }
            if (e.getCreatedAt() == null) {
                e.setCreatedAt(Instant.now());
            }
            return e;
        });

        NotificationView view = service.create(7L, NotificationTypes.FRIEND_REQUEST,
                Map.of("fromUsername", "alice"), "friend-req:1");

        assertThat(view.userId()).isEqualTo(7L);
        assertThat(view.type()).isEqualTo(NotificationTypes.FRIEND_REQUEST);
        assertThat(view.status()).isEqualTo(NotificationStatus.UNREAD);
        verify(deliveryPort).deliver(any(NotificationView.class));
    }

    @Test
    void createWithDedupeReturnsExistingWithoutRedeiver() {
        UUID id = UUID.randomUUID();
        NotificationEntity existing = NotificationEntity.builder()
                .id(id)
                .userId(7L)
                .type(NotificationTypes.FRIEND_REQUEST)
                .payload(Map.of("fromUsername", "alice"))
                .status(NotificationStatus.UNREAD)
                .createdAt(Instant.now())
                .dedupeKey("friend-req:1")
                .build();
        when(repository.findByUserIdAndDedupeKey(7L, "friend-req:1")).thenReturn(Optional.of(existing));

        NotificationView view = service.create(7L, NotificationTypes.FRIEND_REQUEST,
                Map.of("fromUsername", "alice"), "friend-req:1");

        assertThat(view.id()).isEqualTo(id);
        verify(repository, never()).save(any());
        verify(deliveryPort, never()).deliver(any());
    }

    @Test
    void markReadUpdatesUnreadRow() {
        UUID id = UUID.randomUUID();
        NotificationEntity entity = NotificationEntity.builder()
                .id(id)
                .userId(3L)
                .type(NotificationTypes.ROOM_INVITATION)
                .payload(Map.of())
                .status(NotificationStatus.UNREAD)
                .createdAt(Instant.now())
                .build();
        when(repository.findByIdAndUserId(id, 3L)).thenReturn(Optional.of(entity));
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        Optional<NotificationView> result = service.markRead(3L, id);

        assertThat(result).isPresent();
        assertThat(result.get().status()).isEqualTo(NotificationStatus.READ);
        assertThat(result.get().readAt()).isNotNull();
        ArgumentCaptor<NotificationEntity> captor = ArgumentCaptor.forClass(NotificationEntity.class);
        verify(repository).save(captor.capture());
        assertThat(captor.getValue().getStatus()).isEqualTo(NotificationStatus.READ);
    }

    @Test
    void listFiltersByStatus() {
        NotificationEntity entity = NotificationEntity.builder()
                .id(UUID.randomUUID())
                .userId(1L)
                .type(NotificationTypes.GROUP_INVITATION)
                .payload(Map.of())
                .status(NotificationStatus.UNREAD)
                .createdAt(Instant.now())
                .build();
        when(repository.findByUserIdAndStatusOrderByCreatedAtDesc(any(), any(), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(entity)));

        List<NotificationView> list = service.list(1L, NotificationStatus.UNREAD, 0, 10);
        assertThat(list).hasSize(1);
        assertThat(list.get(0).type()).isEqualTo(NotificationTypes.GROUP_INVITATION);
    }
}
