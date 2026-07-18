package com.trustrummy.backend.gamestate;

import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Volatile, in-memory representation of a single room's live gameplay.
 * <p>
 * This object is mutated directly on the hot path (every draw/discard/turn
 * change) and deliberately never touches the database. A background/async
 * writer is responsible for periodically or opportunistically persisting a
 * durable snapshot (see {@code GameMoveLog}) without blocking gameplay.
 */
@Getter
@Setter
public class LiveGameState {

    private final String roomCode;

    /** Ordered turn sequence of user ids. */
    private final List<Long> turnOrder = new CopyOnWriteArrayList<>();

    /** userId -> hand (list of card codes), kept in memory only. */
    private final Map<Long, List<String>> playerHands = new ConcurrentHashMap<>();

    /** userId -> running score for the active session. */
    private final Map<Long, Integer> scores = new ConcurrentHashMap<>();

    private volatile int currentTurnIndex = 0;
    private volatile String status = "WAITING";
    private volatile Long activeSessionId;
    private volatile Instant lastUpdatedAt = Instant.now();

    public LiveGameState(String roomCode) {
        this.roomCode = roomCode;
    }

    public Long currentTurnUserId() {
        if (turnOrder.isEmpty()) {
            return null;
        }
        return turnOrder.get(currentTurnIndex % turnOrder.size());
    }

    public void advanceTurn() {
        if (!turnOrder.isEmpty()) {
            currentTurnIndex = (currentTurnIndex + 1) % turnOrder.size();
        }
        touch();
    }

    public void touch() {
        this.lastUpdatedAt = Instant.now();
    }
}
