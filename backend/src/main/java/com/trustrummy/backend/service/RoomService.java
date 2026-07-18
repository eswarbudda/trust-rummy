package com.trustrummy.backend.service;

import com.trustrummy.backend.dto.RoomCreateRequest;
import com.trustrummy.backend.entity.GameRoom;
import com.trustrummy.backend.entity.RoomPlayer;
import com.trustrummy.backend.entity.RoomStatus;
import com.trustrummy.backend.entity.User;
import com.trustrummy.backend.game.model.GameVariant;
import com.trustrummy.backend.repository.GameRoomRepository;
import com.trustrummy.backend.repository.RoomPlayerRepository;
import com.trustrummy.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.util.List;

@Service
@RequiredArgsConstructor
public class RoomService {

    private static final String CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private static final SecureRandom RANDOM = new SecureRandom();

    private final GameRoomRepository gameRoomRepository;
    private final RoomPlayerRepository roomPlayerRepository;
    private final UserRepository userRepository;
    private final GameStateService gameStateService;

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
