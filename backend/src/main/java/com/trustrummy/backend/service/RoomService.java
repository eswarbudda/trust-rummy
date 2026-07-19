package com.trustrummy.backend.service;

import com.trustrummy.backend.dto.RoomCreateRequest;
import com.trustrummy.backend.entity.GameRoom;
import com.trustrummy.backend.entity.PlayerStatus;
import com.trustrummy.backend.entity.RoomPlayer;
import com.trustrummy.backend.entity.RoomStatus;
import com.trustrummy.backend.entity.User;
import com.trustrummy.backend.exception.ForbiddenOperationException;
import com.trustrummy.backend.exception.ResourceNotFoundException;
import com.trustrummy.backend.game.model.GameType;
import com.trustrummy.backend.game.model.GameVariant;
import com.trustrummy.backend.game.ws.EventType;
import com.trustrummy.backend.game.ws.GameBroadcastService;
import com.trustrummy.backend.game.ws.GameEvent;
import com.trustrummy.backend.repository.GameRoomRepository;
import com.trustrummy.backend.repository.RoomPlayerRepository;
import com.trustrummy.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class RoomService {

    private static final String CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private static final SecureRandom RANDOM = new SecureRandom();

    private final GameRoomRepository gameRoomRepository;
    private final RoomPlayerRepository roomPlayerRepository;
    private final UserRepository userRepository;
    private final GameStateService gameStateService;
    private final GameBroadcastService broadcastService;

    public GameRoom createRoom(String creatorUsername, RoomCreateRequest request) {
        User creator = userRepository.findByUsername(creatorUsername)
                .orElseThrow(() -> new IllegalArgumentException("Unknown user: " + creatorUsername));

        GameRoom room = GameRoom.builder()
                .roomCode(generateUniqueRoomCode())
                .name(request.getName())
                .maxPlayers(request.getMaxPlayers())
                .stakeAmount(request.getStakeAmount())
                .gameType(request.getGameType() != null ? request.getGameType() : GameType.RUMMY)
                .gameVariant(request.getGameVariant() != null ? request.getGameVariant() : GameVariant.POOL_101)
                .status(RoomStatus.WAITING)
                .createdBy(creator)
                .build();

        gameRoomRepository.save(room);

        roomPlayerRepository.save(RoomPlayer.builder()
                .gameRoom(room)
                .user(creator)
                .seatNumber(0)
                .build());

        // Warm up the in-memory state immediately so the first WebSocket
        // handshake into this room never has to wait on a DB round-trip.
        gameStateService.getOrCreate(room.getRoomCode());

        return room;
    }

    public List<GameRoom> listOpenRooms() {
        return gameRoomRepository.findByStatus(RoomStatus.WAITING);
    }

    public GameRoom getRoomByCode(String roomCode) {
        return gameRoomRepository.findByRoomCode(roomCode)
                .orElseThrow(() -> new ResourceNotFoundException("Room not found: " + roomCode));
    }

    /**
     * Seats a user into an existing room by code. This is the piece that was
     * previously missing: connecting the game WebSocket only registers a
     * live session for broadcasts, it does NOT create a {@link RoomPlayer}
     * row — without calling this first, {@code RummyEngineService} never
     * sees the second/third/... player as "seated" and START_MATCH keeps
     * failing with "Need at least 2 seated players to start".
     */
    public GameRoom joinRoom(String username, String roomCode) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalArgumentException("Unknown user: " + username));

        GameRoom room = getRoomByCode(roomCode);

        if (room.getStatus() != RoomStatus.WAITING) {
            throw new IllegalStateException("Room is no longer accepting players");
        }

        Optional<RoomPlayer> existing = roomPlayerRepository.findByGameRoomIdAndUserId(room.getId(), user.getId());
        if (existing.isPresent()) {
            RoomPlayer player = existing.get();
            if (player.getStatus() == PlayerStatus.LEFT) {
                // Re-joining after having left — reactivate the same seat rather than
                // inserting a second row (room_id, user_id) is a unique constraint.
                player.setStatus(PlayerStatus.JOINED);
                player.setLeftAt(null);
                roomPlayerRepository.save(player);
                broadcastRoomState(room);
            }
            return room; // otherwise idempotent: reconnect/refresh shouldn't fail or double-seat
        }

        List<RoomPlayer> seated = getSeatedPlayers(room.getId());
        if (seated.size() >= room.getMaxPlayers()) {
            throw new IllegalStateException("Room is full");
        }

        int nextSeat = seated.stream()
                .mapToInt(rp -> rp.getSeatNumber() == null ? -1 : rp.getSeatNumber())
                .max().orElse(-1) + 1;

        roomPlayerRepository.save(RoomPlayer.builder()
                .gameRoom(room)
                .user(user)
                .seatNumber(nextSeat)
                .build());

        gameStateService.getOrCreate(room.getRoomCode());
        broadcastRoomState(room);

        return room;
    }

    /**
     * Un-seats the caller from a room that hasn't started yet. If the host
     * leaves, the whole room is disbanded — nobody else has "host powers"
     * (only {@code GameRoom.createdBy} can send START_MATCH), so a
     * host-less waiting room could never actually start.
     */
    public void leaveRoom(String username, String roomCode) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalArgumentException("Unknown user: " + username));

        GameRoom room = getRoomByCode(roomCode);
        if (room.getStatus() != RoomStatus.WAITING) {
            throw new IllegalStateException("Cannot leave a room that has already started; drop from the active match instead");
        }

        RoomPlayer player = roomPlayerRepository.findByGameRoomIdAndUserId(room.getId(), user.getId())
                .filter(rp -> rp.getStatus() != PlayerStatus.LEFT)
                .orElseThrow(() -> new ResourceNotFoundException("You are not seated in this room"));

        boolean isHost = room.getCreatedBy() != null && room.getCreatedBy().getId().equals(user.getId());
        if (isHost) {
            disbandRoom(room);
        } else {
            player.setStatus(PlayerStatus.LEFT);
            player.setLeftAt(Instant.now());
            roomPlayerRepository.save(player);
            broadcastRoomState(room);
        }
    }

    /**
     * System-triggered cancellation for a lobby room that's sat in
     * {@code WAITING} too long with nobody around to start or cancel it —
     * called only by the scheduled {@code RoomLifecycleService} reaper.
     * Shares the exact same disband path as a host-initiated cancel.
     */
    public void autoCancelStaleRoom(GameRoom room) {
        disbandRoom(room);
    }

    /** Host-only: closes a waiting room before it starts. */
    public void cancelRoom(String username, String roomCode) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalArgumentException("Unknown user: " + username));

        GameRoom room = getRoomByCode(roomCode);
        if (room.getCreatedBy() == null || !room.getCreatedBy().getId().equals(user.getId())) {
            throw new ForbiddenOperationException("Only the host can cancel this room");
        }
        if (room.getStatus() != RoomStatus.WAITING) {
            throw new IllegalStateException("Only a room that hasn't started can be cancelled");
        }

        disbandRoom(room);
    }

    /** Toggles the caller's ready flag. Purely informational for now — START_MATCH does not currently require it. */
    public GameRoom setReady(String username, String roomCode, boolean ready) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalArgumentException("Unknown user: " + username));

        GameRoom room = getRoomByCode(roomCode);
        if (room.getStatus() != RoomStatus.WAITING) {
            throw new IllegalStateException("Room is no longer in the lobby");
        }

        RoomPlayer player = roomPlayerRepository.findByGameRoomIdAndUserId(room.getId(), user.getId())
                .filter(rp -> rp.getStatus() == PlayerStatus.JOINED || rp.getStatus() == PlayerStatus.READY)
                .orElseThrow(() -> new ResourceNotFoundException("You are not seated in this room"));

        player.setStatus(ready ? PlayerStatus.READY : PlayerStatus.JOINED);
        roomPlayerRepository.save(player);
        broadcastRoomState(room);

        return room;
    }

    /** Currently-seated players (excludes anyone who has {@code LEFT}), sorted by seat number. */
    public List<RoomPlayer> getSeatedPlayers(Long roomId) {
        List<RoomPlayer> seated = new ArrayList<>(roomPlayerRepository.findByGameRoomIdAndStatusNot(roomId, PlayerStatus.LEFT));
        seated.sort(Comparator.comparing(rp -> rp.getSeatNumber() == null ? Integer.MAX_VALUE : rp.getSeatNumber()));
        return seated;
    }

    private void disbandRoom(GameRoom room) {
        room.setStatus(RoomStatus.CANCELLED);
        gameRoomRepository.save(room);

        Instant now = Instant.now();
        getSeatedPlayers(room.getId()).forEach(rp -> {
            rp.setStatus(PlayerStatus.LEFT);
            rp.setLeftAt(now);
            roomPlayerRepository.save(rp);
        });

        gameStateService.remove(room.getRoomCode());
        // Notify any still-connected sockets before wiping the session
        // registry itself, otherwise they'd never see the CANCELLED status.
        broadcastRoomState(room);
        broadcastService.clearRoom(room.getRoomCode());
    }

    /** Lets any already-connected sockets in the room see the new seat/status without reconnecting. */
    private void broadcastRoomState(GameRoom room) {
        List<Map<String, Object>> players = getSeatedPlayers(room.getId()).stream()
                .map(rp -> {
                    Map<String, Object> p = new LinkedHashMap<>();
                    p.put("userId", rp.getUser().getId());
                    p.put("username", rp.getUser().getUsername());
                    p.put("seatNumber", rp.getSeatNumber());
                    p.put("status", rp.getStatus().name());
                    return p;
                })
                .toList();

        broadcastService.broadcast(room.getRoomCode(), GameEvent.of(EventType.ROOM_STATE)
                .with("roomCode", room.getRoomCode())
                .with("matchStatus", room.getStatus().name())
                .with("players", players));
    }

    private String generateUniqueRoomCode() {
        String code;
        do {
            code = randomCode(6);
        } while (gameRoomRepository.findByRoomCode(code).isPresent());
        return code;
    }

    private String randomCode(int length) {
        StringBuilder sb = new StringBuilder(length);
        for (int i = 0; i < length; i++) {
            sb.append(CODE_ALPHABET.charAt(RANDOM.nextInt(CODE_ALPHABET.length())));
        }
        return sb.toString();
    }
}
