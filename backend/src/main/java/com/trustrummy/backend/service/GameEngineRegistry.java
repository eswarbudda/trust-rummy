package com.trustrummy.backend.service;

import com.trustrummy.backend.entity.GameRoom;
import com.trustrummy.backend.game.engine.GameEngine;
import com.trustrummy.backend.game.model.GameType;
import com.trustrummy.backend.repository.GameRoomRepository;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Resolves the {@link GameEngine} responsible for a room. Only one
 * {@link GameType} (RUMMY) has a real engine today, but the transport
 * ({@code GameWebSocketHandler}) and lifecycle ({@code RoomLifecycleService})
 * layers go through this indirection rather than injecting
 * {@code RummyEngineService} directly, so a second game can be added later
 * purely by registering another {@link GameEngine} bean here.
 */
@Service
@RequiredArgsConstructor
public class GameEngineRegistry {

    private final GameRoomRepository gameRoomRepository;
    private final List<GameEngine> engines;

    private Map<GameType, GameEngine> enginesByType;

    @PostConstruct
    void indexEngines() {
        enginesByType = engines.stream()
                .collect(Collectors.toMap(GameEngine::supportedGameType, Function.identity()));
    }

    public GameEngine resolve(GameType gameType) {
        GameEngine engine = enginesByType.get(gameType);
        if (engine == null) {
            throw new IllegalStateException("No GameEngine registered for game type: " + gameType);
        }
        return engine;
    }

    /**
     * Resolves the engine for an already-existing room by its persisted
     * {@code gameType}, defaulting to {@link GameType#RUMMY} if the room
     * (or its {@code gameType}) can't be found — mirrors the same
     * additive-default behavior {@code RoomService.createRoom} uses.
     */
    public GameEngine resolveForRoom(String roomCode) {
        GameType gameType = gameRoomRepository.findByRoomCode(roomCode)
                .map(GameRoom::getGameType)
                .orElse(null);
        return resolve(gameType != null ? gameType : GameType.RUMMY);
    }
}
