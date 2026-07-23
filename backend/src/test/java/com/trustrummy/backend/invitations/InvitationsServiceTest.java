package com.trustrummy.backend.invitations;

import com.trustrummy.backend.exception.ForbiddenOperationException;
import com.trustrummy.backend.friends.FriendPort;
import com.trustrummy.backend.notifications.NotificationPort;
import com.trustrummy.backend.notifications.NotificationTypes;
import com.trustrummy.backend.rooms.RoomPort;
import com.trustrummy.backend.rooms.RoomSummary;
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
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class InvitationsServiceTest {

    @Mock
    private GameInvitationRepository invitationRepository;
    @Mock
    private RoomPort roomPort;
    @Mock
    private UserLookupPort userLookupPort;
    @Mock
    private NotificationPort notificationPort;
    @Mock
    private FriendPort friendPort;

    private InvitationsService service;

    @BeforeEach
    void setUp() {
        service = new InvitationsService(
                invitationRepository, roomPort, userLookupPort, notificationPort, friendPort);
    }

    @Test
    void acceptJoinsRoomThenMarksAccepted() {
        UUID id = UUID.randomUUID();
        GameInvitationEntity invite = pendingInvite(id, 10L, 1L, 2L);
        RoomSummary room = waitingRoom(10L, "ABCD12", 1L);

        when(invitationRepository.findById(id)).thenReturn(Optional.of(invite));
        when(roomPort.requireById(10L)).thenReturn(room);
        when(userLookupPort.findById(2L)).thenReturn(Optional.of(new UserSummary(2L, "bob", "Bob")));
        when(userLookupPort.findById(1L)).thenReturn(Optional.of(new UserSummary(1L, "alice", "Alice")));
        when(roomPort.joinRoom("bob", "ABCD12")).thenReturn(room);
        when(invitationRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        InvitationResponse response = service.accept(2L, id);

        assertThat(response.status()).isEqualTo(InvitationStatus.ACCEPTED);
        assertThat(response.roomCode()).isEqualTo("ABCD12");
        verify(roomPort).joinRoom("bob", "ABCD12");
        ArgumentCaptor<GameInvitationEntity> saved = ArgumentCaptor.forClass(GameInvitationEntity.class);
        verify(invitationRepository).save(saved.capture());
        assertThat(saved.getValue().getStatus()).isEqualTo(InvitationStatus.ACCEPTED);
        verify(notificationPort).create(eq(1L), eq(NotificationTypes.ROOM_INVITATION), any(Map.class), any());
    }

    @Test
    void declineDoesNotJoinRoom() {
        UUID id = UUID.randomUUID();
        GameInvitationEntity invite = pendingInvite(id, 10L, 1L, 2L);
        RoomSummary room = waitingRoom(10L, "ABCD12", 1L);

        when(invitationRepository.findById(id)).thenReturn(Optional.of(invite));
        when(roomPort.requireById(10L)).thenReturn(room);
        when(userLookupPort.findById(1L)).thenReturn(Optional.of(new UserSummary(1L, "alice", "Alice")));
        when(userLookupPort.findById(2L)).thenReturn(Optional.of(new UserSummary(2L, "bob", "Bob")));
        when(invitationRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        InvitationResponse response = service.decline(2L, id);

        assertThat(response.status()).isEqualTo(InvitationStatus.DECLINED);
        verify(roomPort, never()).joinRoom(any(), any());
    }

    @Test
    void createBatchNotifiesInvitees() {
        RoomSummary room = waitingRoom(10L, "ABCD12", 1L);
        when(roomPort.requireById(10L)).thenReturn(room);
        when(userLookupPort.findById(1L)).thenReturn(Optional.of(new UserSummary(1L, "alice", "Alice")));
        when(userLookupPort.findById(2L)).thenReturn(Optional.of(new UserSummary(2L, "bob", "Bob")));
        when(invitationRepository.findByRoomIdAndInviteeId(10L, 2L)).thenReturn(Optional.empty());
        when(invitationRepository.save(any())).thenAnswer(inv -> {
            GameInvitationEntity e = inv.getArgument(0);
            if (e.getId() == null) {
                e.setId(UUID.randomUUID());
            }
            if (e.getCreatedAt() == null) {
                e.setCreatedAt(Instant.now());
            }
            return e;
        });

        List<InvitationView> created = service.createBatch(new CreateInvitationsCommand(
                10L, 5L, 1L, List.of(2L), Instant.now().plusSeconds(600)
        ));

        assertThat(created).hasSize(1);
        verify(notificationPort).create(
                eq(2L),
                eq(NotificationTypes.GROUP_INVITATION),
                any(Map.class),
                any()
        );
    }

    @Test
    void inviteToRoomRequiresFriendship() {
        RoomSummary room = waitingRoom(10L, "ABCD12", 1L);
        when(roomPort.requireByCode("ABCD12")).thenReturn(room);
        when(friendPort.areFriends(1L, 2L)).thenReturn(false);

        assertThatThrownBy(() -> service.inviteToRoom(1L, "ABCD12", 2L))
                .isInstanceOf(ForbiddenOperationException.class);
        verify(invitationRepository, never()).save(any());
    }

    @Test
    void nonInviteeCannotAccept() {
        UUID id = UUID.randomUUID();
        when(invitationRepository.findById(id)).thenReturn(Optional.of(pendingInvite(id, 10L, 1L, 2L)));

        assertThatThrownBy(() -> service.accept(99L, id))
                .isInstanceOf(ForbiddenOperationException.class);
    }

    private static GameInvitationEntity pendingInvite(UUID id, long roomId, long inviterId, long inviteeId) {
        return GameInvitationEntity.builder()
                .id(id)
                .roomId(roomId)
                .inviterId(inviterId)
                .inviteeId(inviteeId)
                .status(InvitationStatus.PENDING)
                .channel(InvitationChannel.IN_APP)
                .expiresAt(Instant.now().plusSeconds(600))
                .createdAt(Instant.now())
                .build();
    }

    private static RoomSummary waitingRoom(long id, String code, long hostId) {
        return new RoomSummary(id, code, "WAITING", hostId, "alice", 6, "Table");
    }
}
