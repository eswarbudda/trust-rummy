package com.trustrummy.backend.friends;

import com.trustrummy.backend.exception.ForbiddenOperationException;
import com.trustrummy.backend.notifications.NotificationPort;
import com.trustrummy.backend.notifications.NotificationTypes;
import com.trustrummy.backend.notifications.NotificationView;
import com.trustrummy.backend.presence.PresenceService;
import com.trustrummy.backend.users.UserLookupPort;
import com.trustrummy.backend.users.UserSummary;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class FriendsServiceTest {

    @Mock
    private FriendshipRepository friendshipRepository;
    @Mock
    private UserLookupPort userLookupPort;
    @Mock
    private NotificationPort notificationPort;
    @Mock
    private PresenceService presenceService;

    private FriendsService service;

    @BeforeEach
    void setUp() {
        service = new FriendsService(friendshipRepository, userLookupPort, notificationPort, presenceService);
    }

    @Test
    void sendRequestCreatesPendingAndNotifies() {
        when(userLookupPort.findById(2L)).thenReturn(Optional.of(new UserSummary(2L, "bob", "Bob")));
        when(userLookupPort.findById(1L)).thenReturn(Optional.of(new UserSummary(1L, "alice", "Alice")));
        when(friendshipRepository.findPair(1L, 2L)).thenReturn(Optional.empty());
        when(friendshipRepository.save(any())).thenAnswer(inv -> {
            FriendshipEntity e = inv.getArgument(0);
            e.setId(10L);
            e.setCreatedAt(Instant.now());
            e.setUpdatedAt(Instant.now());
            return e;
        });
        when(notificationPort.create(anyLong(), anyString(), anyMap(), anyString()))
                .thenReturn(sampleNotification());

        FriendshipView view = service.sendRequestByUserId(1L, 2L);

        assertThat(view.friendshipId()).isEqualTo(10L);
        assertThat(view.status()).isEqualTo(FriendshipStatus.PENDING);
        @SuppressWarnings("unchecked")
        ArgumentCaptor<Map<String, Object>> payload = ArgumentCaptor.forClass(Map.class);
        verify(notificationPort).create(
                eq(2L),
                eq(NotificationTypes.FRIEND_REQUEST),
                payload.capture(),
                anyString()
        );
        assertThat(payload.getValue()).containsEntry("fromUsername", "alice");
        assertThat(payload.getValue()).containsEntry("friendshipId", 10L);
    }

    @Test
    void sendRequestRejectsSelf() {
        assertThatThrownBy(() -> service.sendRequestByUserId(1L, 1L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Cannot friend yourself");
        verify(notificationPort, never()).create(anyLong(), anyString(), anyMap(), anyString());
    }

    @Test
    void acceptNotifiesRequester() {
        FriendshipEntity pending = FriendshipEntity.builder()
                .id(10L)
                .requesterId(1L)
                .addresseeId(2L)
                .status(FriendshipStatus.PENDING)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
        when(friendshipRepository.findById(10L)).thenReturn(Optional.of(pending));
        when(friendshipRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(userLookupPort.findById(2L)).thenReturn(Optional.of(new UserSummary(2L, "bob", "Bob")));
        when(notificationPort.create(anyLong(), anyString(), anyMap(), anyString()))
                .thenReturn(sampleNotification());

        FriendshipView view = service.accept(2L, 10L);

        assertThat(view.status()).isEqualTo(FriendshipStatus.ACCEPTED);
        verify(notificationPort).create(
                eq(1L),
                eq(NotificationTypes.FRIEND_ACCEPTED),
                anyMap(),
                eq("friend-accepted:10")
        );
    }

    @Test
    void acceptForbiddenForRequester() {
        FriendshipEntity pending = FriendshipEntity.builder()
                .id(10L)
                .requesterId(1L)
                .addresseeId(2L)
                .status(FriendshipStatus.PENDING)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
        when(friendshipRepository.findById(10L)).thenReturn(Optional.of(pending));

        assertThatThrownBy(() -> service.accept(1L, 10L))
                .isInstanceOf(ForbiddenOperationException.class)
                .hasMessageContaining("addressee");
    }

    @Test
    void listFriendsIncludesOnlineFlags() {
        FriendshipEntity friendship = FriendshipEntity.builder()
                .id(5L)
                .requesterId(1L)
                .addresseeId(2L)
                .status(FriendshipStatus.ACCEPTED)
                .createdAt(Instant.parse("2026-01-01T00:00:00Z"))
                .respondedAt(Instant.parse("2026-01-02T00:00:00Z"))
                .updatedAt(Instant.parse("2026-01-02T00:00:00Z"))
                .build();
        when(friendshipRepository.findByUserAndStatus(1L, FriendshipStatus.ACCEPTED))
                .thenReturn(List.of(friendship));
        when(userLookupPort.findByIds(List.of(2L)))
                .thenReturn(Map.of(2L, new UserSummary(2L, "bob", "Bob")));
        when(presenceService.filterOnline(List.of(2L))).thenReturn(Set.of(2L));

        List<FriendResponse> friends = service.listFriends(1L);

        assertThat(friends).hasSize(1);
        assertThat(friends.get(0).username()).isEqualTo("bob");
        assertThat(friends.get(0).online()).isTrue();
    }

    @Test
    void areFriendsDelegatesToRepository() {
        when(friendshipRepository.areFriends(1L, 2L)).thenReturn(true);
        assertThat(service.areFriends(1L, 2L)).isTrue();
    }

    @Test
    void reRequestAfterRemovedReopensPending() {
        FriendshipEntity removed = FriendshipEntity.builder()
                .id(9L)
                .requesterId(2L)
                .addresseeId(1L)
                .status(FriendshipStatus.REMOVED)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
        when(userLookupPort.findById(2L)).thenReturn(Optional.of(new UserSummary(2L, "bob", "Bob")));
        when(userLookupPort.findById(1L)).thenReturn(Optional.of(new UserSummary(1L, "alice", "Alice")));
        when(friendshipRepository.findPair(1L, 2L)).thenReturn(Optional.of(removed));
        when(friendshipRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(notificationPort.create(anyLong(), anyString(), anyMap(), anyString()))
                .thenReturn(sampleNotification());

        FriendshipView view = service.sendRequestByUserId(1L, 2L);

        assertThat(view.status()).isEqualTo(FriendshipStatus.PENDING);
        assertThat(view.requesterId()).isEqualTo(1L);
        assertThat(view.addresseeId()).isEqualTo(2L);
    }

    private static NotificationView sampleNotification() {
        return new NotificationView(
                UUID.randomUUID(),
                2L,
                NotificationTypes.FRIEND_REQUEST,
                Map.of(),
                com.trustrummy.backend.notifications.NotificationStatus.UNREAD,
                Instant.now(),
                null,
                "friend-req:10"
        );
    }
}
