package com.trustrummy.backend.service;

import com.trustrummy.backend.game.state.MatchState;
import org.springframework.stereotype.Service;

import java.util.Collection;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Central, thread-safe registry of every currently-live room match.
 * <p>
 * The live gameplay loop (turn changes, draws, discards, declares) reads
 * and writes exclusively through this in-memory {@link ConcurrentHashMap},
 * completely bypassing the database on the hot path. Durable persistence
 * (audit log, final results) happens asynchronously via
 * {@link GamePersistenceService} once a match ends or on periodic
 * checkpoints.
 */
@Service
public class GameStateService {

    private final ConcurrentHashMap<String, MatchState> roomStates = new ConcurrentHashMap<>();

    /**
     * Atomically fetches the live match for a room, creating one if it does
     * not yet exist. Safe to call concurrently from multiple WebSocket
     * sessions handshaking into the same room.
     */
    public MatchState getOrCreate(String roomCode) {
        return roomStates.computeIfAbsent(roomCode, MatchState::new);
    }

    public MatchState get(String roomCode) {
        return roomStates.get(roomCode);
    }

    public boolean exists(String roomCode) {
        return roomStates.containsKey(roomCode);
    }

    public void remove(String roomCode) {
        roomStates.remove(roomCode);
    }

    public Collection<MatchState> activeRooms() {
        return roomStates.values();
    }

    public int activeRoomCount() {
        return roomStates.size();
    }
}
