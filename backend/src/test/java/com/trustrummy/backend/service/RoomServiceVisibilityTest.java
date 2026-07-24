package com.trustrummy.backend.service;

import com.trustrummy.backend.dto.RoomCreateRequest;
import com.trustrummy.backend.entity.GameRoom;
import com.trustrummy.backend.entity.RoomStatus;
import com.trustrummy.backend.entity.RoomVisibility;
import com.trustrummy.backend.entity.User;
import com.trustrummy.backend.exception.ForbiddenOperationException;
import com.trustrummy.backend.game.model.GameVariant;
import com.trustrummy.backend.game.ws.GameBroadcastService;
import com.trustrummy.backend.repository.GameRoomRepository;
import com.trustrummy.backend.repository.RoomPlayerRepository;
import com.trustrummy.backend.repository.UserRepository;
import com.trustrummy.backend.rooms.GroupRoomAccessPort;
import com.trustrummy.backend.rooms.PrivateRoomInvitePort;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RoomServiceVisibilityTest {

    @Mock
    private GameRoomRepository gameRoomRepository;
    @Mock
    private RoomPlayerRepository roomPlayerRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private GameStateService gameStateService;
    @Mock
    private GameBroadcastService broadcastService;
    @Mock
    private PrivateRoomInvitePort privateRoomInvitePort;
    @Mock
    private GroupRoomAccessPort groupRoomAccessPort;

    private RoomService service;

    @BeforeEach
    void setUp() {
        service = new RoomService(
                gameRoomRepository,
                roomPlayerRepository,
                userRepository,
                gameStateService,
                broadcastService,
                privateRoomInvitePort,
                groupRoomAccessPort
        );
    }

    @Test
    void createRoomDefaultsToPublicVisibility() {
        User alice = user(1L, "alice");
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(alice));
        when(gameRoomRepository.findByRoomCode(any())).thenReturn(Optional.empty());
        when(gameRoomRepository.save(any())).thenAnswer(inv -> {
            GameRoom room = inv.getArgument(0);
            room.setId(10L);
            return room;
        });
        when(roomPlayerRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        RoomCreateRequest request = new RoomCreateRequest();
        request.setName("Table");
        request.setMaxPlayers(4);
        request.setStakeAmount(BigDecimal.ZERO);
        request.setGameVariant(GameVariant.POOL_101);

        GameRoom room = service.createRoom("alice", request);

        assertThat(room.getVisibility()).isEqualTo(RoomVisibility.PUBLIC);
        assertThat(room.getSourceGroupId()).isNull();
    }

    @Test
    void listOpenRoomsQueriesPublicWaitingOnly() {
        when(gameRoomRepository.findByStatusAndVisibility(RoomStatus.WAITING, RoomVisibility.PUBLIC))
                .thenReturn(List.of());

        service.listOpenRooms();

        verify(gameRoomRepository).findByStatusAndVisibility(RoomStatus.WAITING, RoomVisibility.PUBLIC);
        verify(gameRoomRepository, never()).findByStatus(any());
    }

    @Test
    void joinPrivateRoomRequiresInvitation() {
        User bob = user(2L, "bob");
        GameRoom room = GameRoom.builder()
                .id(10L)
                .roomCode("PRIV01")
                .maxPlayers(4)
                .status(RoomStatus.WAITING)
                .visibility(RoomVisibility.PRIVATE)
                .build();
        when(userRepository.findByUsername("bob")).thenReturn(Optional.of(bob));
        when(gameRoomRepository.findByRoomCode("PRIV01")).thenReturn(Optional.of(room));
        when(roomPlayerRepository.findByGameRoomIdAndUserId(10L, 2L)).thenReturn(Optional.empty());
        when(privateRoomInvitePort.hasJoinableInvite(10L, 2L)).thenReturn(false);

        assertThatThrownBy(() -> service.joinRoom("bob", "PRIV01"))
                .isInstanceOf(ForbiddenOperationException.class)
                .hasMessageContaining("invitation");
    }

    @Test
    void joinGroupOnlyRoomAllowsActiveMember() {
        User bob = user(2L, "bob");
        GameRoom room = GameRoom.builder()
                .id(10L)
                .roomCode("GRP001")
                .maxPlayers(4)
                .status(RoomStatus.WAITING)
                .visibility(RoomVisibility.GROUP_ONLY)
                .sourceGroupId(55L)
                .build();
        when(userRepository.findByUsername("bob")).thenReturn(Optional.of(bob));
        when(gameRoomRepository.findByRoomCode("GRP001")).thenReturn(Optional.of(room));
        when(roomPlayerRepository.findByGameRoomIdAndUserId(10L, 2L)).thenReturn(Optional.empty());
        when(groupRoomAccessPort.isActiveMember(55L, 2L)).thenReturn(true);
        when(roomPlayerRepository.findByGameRoomIdAndStatusNot(eq(10L), any()))
                .thenReturn(List.of());
        when(roomPlayerRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        GameRoom joined = service.joinRoom("bob", "GRP001");

        assertThat(joined.getRoomCode()).isEqualTo("GRP001");
        verify(roomPlayerRepository).save(any());
        verify(privateRoomInvitePort, never()).hasJoinableInvite(anyLong(), anyLong());
    }

    @Test
    void createGroupOnlyWithoutSourceGroupFails() {
        User alice = user(1L, "alice");
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(alice));

        RoomCreateRequest request = new RoomCreateRequest();
        request.setName("Group table");
        request.setMaxPlayers(4);
        request.setStakeAmount(BigDecimal.ZERO);
        request.setVisibility(RoomVisibility.GROUP_ONLY);

        assertThatThrownBy(() -> service.createRoom("alice", request))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("sourceGroupId");
    }

    @Test
    void createPersistsPrivateVisibility() {
        User alice = user(1L, "alice");
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(alice));
        when(gameRoomRepository.findByRoomCode(any())).thenReturn(Optional.empty());
        ArgumentCaptor<GameRoom> captor = ArgumentCaptor.forClass(GameRoom.class);
        when(gameRoomRepository.save(captor.capture())).thenAnswer(inv -> {
            GameRoom room = inv.getArgument(0);
            room.setId(11L);
            return room;
        });
        when(roomPlayerRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        RoomCreateRequest request = new RoomCreateRequest();
        request.setName("Rematch");
        request.setMaxPlayers(2);
        request.setStakeAmount(BigDecimal.ZERO);
        request.setVisibility(RoomVisibility.PRIVATE);

        service.createRoom("alice", request);

        assertThat(captor.getValue().getVisibility()).isEqualTo(RoomVisibility.PRIVATE);
    }

    private static User user(long id, String username) {
        User u = new User();
        u.setId(id);
        u.setUsername(username);
        return u;
    }
}
