package com.trustrummy.backend.service;

import com.trustrummy.backend.gamestate.LiveGameState;
import org.springframework.stereotype.Service;

import java.util.Collection;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Central, thread-safe registry of every currently-live game room.
 * <p>
 * The live gameplay loop (turn changes, draws, discards, declares) reads
 * and writes exclusively through this in-memory {@link ConcurrentHashMap},
 * completely bypassing the database on the hot path. Durable persistence
 * (audit log, final results) happens asynchronously via the JPA
 * repositories once a session ends or on periodic checkpoints.
 */
@Service
public class GameStateService {

    private final ConcurrentHashMap<String, LiveGameState> roomStates = new ConcurrentHashMap<>();

    /**
     * Atomically fetches the live state for a room, creating one if it does
     * not yet exist. Safe to call concurrently from multiple WebSocket
     * sessions handshaking into the same room.
     */
    public LiveGameState getOrCreate(String roomCode) {
        return roomStates.computeIfAbsent(roomCode, LiveGameState::new);
    }

    public LiveGameState get(String roomCode) {
        return roomStates.get(roomCode);
    }

    public boolean exists(String roomCode) {
        return roomStates.containsKey(roomCode);
    }

    public void remove(String roomCode) {
        roomStates.remove(roomCode);
    }

    public Collection<LiveGameState> activeRooms() {
        return roomStates.values();
    }

    public int activeRoomCount() {
        return roomStates.size();
    }
}
