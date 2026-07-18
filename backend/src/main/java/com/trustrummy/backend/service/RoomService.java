package com.trustrummy.backend.service;

import com.trustrummy.backend.dto.RoomCreateRequest;
import com.trustrummy.backend.entity.GameRoom;
import com.trustrummy.backend.entity.RoomPlayer;
import com.trustrummy.backend.entity.RoomStatus;
import com.trustrummy.backend.entity.User;
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

        GameRoom room = gameRoomRepository.findByRoomCode(roomCode)
                .orElseThrow(() -> new IllegalArgumentException("Room not found: " + roomCode));

        if (room.getStatus() != RoomStatus.WAITING) {
            throw new IllegalStateException("Room is no longer accepting players");
        }

        Optional<RoomPlayer> existing = roomPlayerRepository.findByGameRoomIdAndUserId(room.getId(), user.getId());
        if (existing.isPresent()) {
            return room; // idempotent: reconnect/refresh shouldn't fail or double-seat
        }

        List<RoomPlayer> seated = roomPlayerRepository.findByGameRoomId(room.getId());
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

    public List<RoomPlayer> getSeatedPlayers(Long roomId) {
        List<RoomPlayer> seated = new ArrayList<>(roomPlayerRepository.findByGameRoomId(roomId));
        seated.sort(Comparator.comparing(rp -> rp.getSeatNumber() == null ? Integer.MAX_VALUE : rp.getSeatNumber()));
        return seated;
    }

    /** Lets any already-connected sockets in the room see the new seat count without reconnecting. */
    private void broadcastRoomState(GameRoom room) {
        List<Map<String, Object>> players = getSeatedPlayers(room.getId()).stream()
                .map(rp -> {
                    Map<String, Object> p = new LinkedHashMap<>();
                    p.put("userId", rp.getUser().getId());
                    p.put("username", rp.getUser().getUsername());
                    p.put("seatNumber", rp.getSeatNumber());
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
