package com.trustrummy.backend.game.state;

import com.trustrummy.backend.game.config.GameConfig;
import com.trustrummy.backend.game.model.MatchPlayerStatus;
import com.trustrummy.backend.game.model.MatchStatus;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.locks.ReentrantLock;

/**
 * Root, in-memory representation of a single room's live match. Replaces
 * the phase-1/2 {@code LiveGameState} stub with the full multi-deal
 * lifecycle: configurable rules, per-player cumulative scorecards, and the
 * currently active {@link Deal}.
 * <p>
 * Registered in {@code GameStateService}'s {@code ConcurrentHashMap} —
 * one instance per live room, created on demand and torn down when the
 * match ends. All mutation for a room's match funnels through
 * {@code RummyEngineService}, which holds {@link #getLock()} for the
 * duration of each action so draw+discard/drop/declare stay atomic even
 * under concurrent WebSocket messages.
 */
@Getter
@Setter
public class MatchState {

    private final String roomCode;
    private final ReentrantLock lock = new ReentrantLock();

    /** Stable seat order for the whole match (does not change between deals). */
    private final List<Long> seatOrder = new CopyOnWriteArrayList<>();

    /** userId -> cumulative scorecard, persists across every deal in the match. */
    private final Map<Long, PlayerScorecard> scorecards = new ConcurrentHashMap<>();

    private volatile GameConfig config = GameConfig.defaults();
    private volatile MatchStatus status = MatchStatus.WAITING;
    private volatile int dealNumber = 0;
    private volatile Deal currentDeal;
    private volatile Long matchWinnerId;
    private volatile Instant lastUpdatedAt = Instant.now();

    /** Per-player stake collected from {@code GameRoom.stakeAmount} at {@code START_MATCH} time; zero for free-play rooms. */
    private volatile BigDecimal stakeAmount = BigDecimal.ZERO;

    public MatchState(String roomCode) {
        this.roomCode = roomCode;
    }

    public List<Long> activeMatchPlayerIds() {
        List<Long> active = new ArrayList<>();
        for (Long userId : seatOrder) {
            PlayerScorecard card = scorecards.get(userId);
            if (card != null && card.getMatchStatus() == MatchPlayerStatus.ACTIVE) {
                active.add(userId);
            }
        }
        return active;
    }

    public void touch() {
        this.lastUpdatedAt = Instant.now();
    }
}
