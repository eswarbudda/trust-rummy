package com.trustrummy.backend.game.state;

import com.trustrummy.backend.game.model.Card;
import com.trustrummy.backend.game.model.DealStatus;
import com.trustrummy.backend.game.model.RoundStatus;
import com.trustrummy.backend.game.model.TurnPhase;
import com.trustrummy.backend.game.model.Value;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Volatile, in-memory state for a single deal (one 13-card hand) within a
 * match. Mutated directly on the hot path by {@code RummyEngineService};
 * never touches the database directly.
 */
@Getter
@Setter
public class Deal {

    private final int dealNumber;

    /** Fixed seat rotation for this deal; membership never changes mid-deal (dropped players are skipped, not removed). */
    private final List<Long> turnOrder = new CopyOnWriteArrayList<>();

    /** Cards not yet drawn, face down. Top of deck = first element. */
    private final Deque<Card> closedDeck = new ArrayDeque<>();

    /** Discard pile; top (most recently discarded) card = first element (peekFirst). */
    private final Deque<Card> discardPile = new ArrayDeque<>();

    /** userId -> current hand. */
    private final Map<Long, List<Card>> hands = new ConcurrentHashMap<>();

    /** userId -> status within this deal only. */
    private final Map<Long, RoundStatus> roundStatus = new ConcurrentHashMap<>();

    /** userId -> whether they have completed at least one full turn (draw+discard) this deal. */
    private final Map<Long, Boolean> hasCompletedFirstTurn = new ConcurrentHashMap<>();

    /**
     * userId -> points already applied mid-deal (drop / wrong declare) so
     * {@code SCORE_UPDATE} / {@code DEAL_RESULT} can show the same deal penalty.
     */
    private final Map<Long, Integer> appliedRoundPoints = new ConcurrentHashMap<>();

    private volatile Card cutJokerCard;
    private volatile Value wildValue;
    private volatile int currentTurnIndex = 0;
    private volatile TurnPhase turnPhase = TurnPhase.AWAITING_DRAW;
    private volatile DealStatus status = DealStatus.IN_PROGRESS;
    private volatile Long declarerUserId;
    private volatile Instant turnStartedAt = Instant.now();
    private volatile Instant lastUpdatedAt = Instant.now();

    public Deal(int dealNumber) {
        this.dealNumber = dealNumber;
    }

    public Long currentTurnUserId() {
        if (turnOrder.isEmpty()) {
            return null;
        }
        return turnOrder.get(currentTurnIndex);
    }

    public int activePlayerCount() {
        return (int) roundStatus.values().stream().filter(s -> s == RoundStatus.PLAYING).count();
    }

    public List<Long> activePlayerIds() {
        List<Long> active = new ArrayList<>();
        for (Long userId : turnOrder) {
            if (roundStatus.get(userId) == RoundStatus.PLAYING) {
                active.add(userId);
            }
        }
        return active;
    }

    /** Advances to the next PLAYING player in seat order, skipping dropped/declared seats. */
    public void advanceTurn() {
        int size = turnOrder.size();
        if (size == 0) {
            return;
        }
        int attempts = 0;
        do {
            currentTurnIndex = (currentTurnIndex + 1) % size;
            attempts++;
        } while (roundStatus.get(turnOrder.get(currentTurnIndex)) != RoundStatus.PLAYING && attempts <= size);
        turnPhase = TurnPhase.AWAITING_DRAW;
        touch();
    }

    public Card peekDiscardTop() {
        return discardPile.peekFirst();
    }

    public Card drawFromClosed() {
        return closedDeck.pollFirst();
    }

    public Card drawFromOpen() {
        return discardPile.pollFirst();
    }

    public void discard(Card card) {
        discardPile.addFirst(card);
    }

    /** Used when a player drops: their hand is stripped and shuffled back into the closed deck. */
    public void returnCardsToClosedDeckShuffled(List<Card> cards) {
        List<Card> merged = new ArrayList<>(closedDeck);
        merged.addAll(cards);
        java.util.Collections.shuffle(merged, new java.security.SecureRandom());
        closedDeck.clear();
        closedDeck.addAll(merged);
    }

    /** Reshuffles the discard pile (minus its current top card) back into a fresh closed deck. */
    public void reshuffleDiscardIntoClosedDeck() {
        Card top = discardPile.pollFirst();
        List<Card> rest = new ArrayList<>(discardPile);
        discardPile.clear();
        java.util.Collections.shuffle(rest, new java.security.SecureRandom());
        closedDeck.addAll(rest);
        if (top != null) {
            discardPile.addFirst(top);
        }
    }

    public void touch() {
        this.lastUpdatedAt = Instant.now();
    }
}
