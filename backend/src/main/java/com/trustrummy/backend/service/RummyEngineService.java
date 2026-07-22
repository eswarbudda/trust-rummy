package com.trustrummy.backend.service;

import com.trustrummy.backend.entity.GameRoom;
import com.trustrummy.backend.entity.MoveType;
import com.trustrummy.backend.entity.PlayerStatus;
import com.trustrummy.backend.entity.RoomPlayer;
import com.trustrummy.backend.entity.RoomStatus;
import com.trustrummy.backend.game.config.GameConfig;
import com.trustrummy.backend.game.engine.DeckFactory;
import com.trustrummy.backend.game.engine.GameEngine;
import com.trustrummy.backend.game.engine.HandValidator;
import com.trustrummy.backend.game.engine.ScoreCalculator;
import com.trustrummy.backend.game.engine.TurnManager;
import com.trustrummy.backend.game.model.Card;
import com.trustrummy.backend.game.model.DealStatus;
import com.trustrummy.backend.game.model.DeclareResult;
import com.trustrummy.backend.game.model.GameType;
import com.trustrummy.backend.game.model.GameVariant;
import com.trustrummy.backend.game.model.GroupingResult;
import com.trustrummy.backend.game.model.MatchPlayerStatus;
import com.trustrummy.backend.game.model.MatchStatus;
import com.trustrummy.backend.game.model.Meld;
import com.trustrummy.backend.game.model.MeldType;
import com.trustrummy.backend.game.model.RoundStatus;
import com.trustrummy.backend.game.model.TurnPhase;
import com.trustrummy.backend.game.model.Value;
import com.trustrummy.backend.game.state.Deal;
import com.trustrummy.backend.game.state.MatchState;
import com.trustrummy.backend.game.state.PlayerScorecard;
import com.trustrummy.backend.game.ws.ActionType;
import com.trustrummy.backend.game.ws.DrawSource;
import com.trustrummy.backend.game.ws.EventType;
import com.trustrummy.backend.game.ws.GameActionMessage;
import com.trustrummy.backend.game.ws.GameBroadcastService;
import com.trustrummy.backend.game.ws.GameEvent;
import com.trustrummy.backend.repository.GameRoomRepository;
import com.trustrummy.backend.repository.RoomPlayerRepository;
import com.trustrummy.backend.service.settlement.CollectStakesCommand;
import com.trustrummy.backend.service.settlement.CollectStakesResult;
import com.trustrummy.backend.service.settlement.MatchSettlementService;
import com.trustrummy.backend.service.settlement.SeatedPlayer;
import com.trustrummy.backend.service.settlement.SettleStakesCommand;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Orchestrator for the entire 13-card Indian Pool/Points Rummy engine.
 * This is the single entry point the WebSocket layer calls; every mutation
 * to a room's {@link MatchState} happens here, under that match's lock, so
 * concurrent messages for the same room are processed atomically.
 * <p>
 * See {@code RULES_ENGINE.md} at the repo root for the full state-machine
 * and WebSocket contract this class implements.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RummyEngineService implements GameEngine {

    private final GameStateService gameStateService;
    private final GameRoomRepository gameRoomRepository;
    private final RoomPlayerRepository roomPlayerRepository;
    private final HandValidator handValidator;
    private final ScoreCalculator scoreCalculator;
    private final TurnManager turnManager;
    private final GameBroadcastService broadcastService;
    private final GamePersistenceService persistenceService;
    private final MatchSettlementService matchSettlementService;

    private final Map<String, AtomicLong> sequenceCounters = new ConcurrentHashMap<>();

    // ------------------------------------------------------------------
    // Entry point
    // ------------------------------------------------------------------

    @Override
    public GameType supportedGameType() {
        return GameType.RUMMY;
    }

    @Override
    public void handleAction(String roomCode, Long userId, GameActionMessage action) {
        MatchState match = gameStateService.getOrCreate(roomCode);

        if (action.getType() == ActionType.START_MATCH) {
            match.getLock().lock();
            try {
                startMatch(match, userId);
            } finally {
                match.getLock().unlock();
            }
            return;
        }

        if (action.getType() == ActionType.START_NEXT_DEAL) {
            match.getLock().lock();
            try {
                handleStartNextDeal(match, userId);
            } finally {
                match.getLock().unlock();
            }
            return;
        }

        if (action.getType() == ActionType.LEAVE_TABLE) {
            match.getLock().lock();
            try {
                handleLeaveTable(match, userId);
            } finally {
                match.getLock().unlock();
            }
            return;
        }

        match.getLock().lock();
        try {
            Deal deal = match.getCurrentDeal();
            if (match.getStatus() == MatchStatus.BETWEEN_DEALS) {
                sendError(roomCode, userId, "Deal result is showing — wait for the next deal");
                return;
            }
            if (match.getStatus() != MatchStatus.IN_PROGRESS || deal == null || deal.getStatus() != DealStatus.IN_PROGRESS) {
                sendError(roomCode, userId, "No active deal in progress");
                return;
            }
            if (!userId.equals(deal.currentTurnUserId())) {
                sendError(roomCode, userId, "It is not your turn");
                return;
            }

            switch (action.getType()) {
                case DRAW_CARD -> handleDraw(match, deal, userId, action.getSource());
                case DISCARD_CARD -> handleDiscard(match, deal, userId, action.getCardCode());
                case DECLARE -> handleDeclare(match, deal, userId, action.getCardCode());
                case DROP -> handleDrop(match, deal, userId);
                default -> sendError(roomCode, userId, "Unsupported action");
            }
        } finally {
            match.getLock().unlock();
        }
    }

    /** Builds a personalized snapshot for a freshly connected session (e.g. on WebSocket handshake). */
    @Override
    public GameEvent buildSnapshotEventFor(String roomCode, Long userId) {
        MatchState match = gameStateService.getOrCreate(roomCode);
        if (match.getCurrentDeal() == null) {
            return GameEvent.of(EventType.ROOM_STATE)
                    .with("roomCode", roomCode)
                    .with("matchStatus", match.getStatus().name());
        }
        return buildDealEvent(EventType.ROOM_STATE, match, match.getCurrentDeal(), userId);
    }

    // ------------------------------------------------------------------
    // Match / deal lifecycle
    // ------------------------------------------------------------------

    private void startMatch(MatchState match, Long requesterUserId) {
        if (match.getStatus() != MatchStatus.WAITING) {
            sendError(match.getRoomCode(), requesterUserId, "Match already started");
            return;
        }

        GameRoom room = gameRoomRepository.findByRoomCode(match.getRoomCode()).orElse(null);
        if (room == null) {
            sendError(match.getRoomCode(), requesterUserId, "Room not found");
            return;
        }
        if (room.getCreatedBy() == null || !room.getCreatedBy().getId().equals(requesterUserId)) {
            sendError(match.getRoomCode(), requesterUserId, "Only the host can start the match");
            return;
        }
        if (room.getStatus() != RoomStatus.WAITING) {
            sendError(match.getRoomCode(), requesterUserId,
                    "Room is not waiting for a match start (status=" + room.getStatus() + ")");
            return;
        }

        List<RoomPlayer> seated = new ArrayList<>(roomPlayerRepository.findByGameRoomIdAndStatusNot(room.getId(), PlayerStatus.LEFT));
        seated.sort(Comparator.comparing(rp -> rp.getSeatNumber() == null ? Integer.MAX_VALUE : rp.getSeatNumber()));
        if (seated.size() < 2) {
            sendError(match.getRoomCode(), requesterUserId, "Need at least 2 seated players to start");
            return;
        }

        BigDecimal stake = room.getStakeAmount() != null ? room.getStakeAmount() : BigDecimal.ZERO;
        match.setStakeAmount(stake);
        CollectStakesResult collectResult = matchSettlementService.collectStakes(new CollectStakesCommand(
                match.getRoomCode(),
                stake,
                seated.stream()
                        .map(rp -> new SeatedPlayer(rp.getUser().getId(), rp.getUser().getUsername()))
                        .toList()));
        if (!collectResult.success()) {
            sendError(match.getRoomCode(), requesterUserId, collectResult.errorMessage());
            return; // rejection/refund already handled by settlement; match state untouched
        }

        GameVariant variant = room.getGameVariant() != null ? room.getGameVariant() : GameVariant.POOL_101;
        Integer dealsPerMatch = resolveDealsPerMatch(variant, room.getDealsPerMatch());
        GameConfig config = GameConfig.builder()
                .maxPlayers(room.getMaxPlayers())
                .gameVariant(variant)
                .dealsPerMatch(dealsPerMatch)
                .build();
        match.setConfig(config);

        match.getSeatOrder().clear();
        match.getScorecards().clear();
        for (RoomPlayer rp : seated) {
            Long userId = rp.getUser().getId();
            match.getSeatOrder().add(userId);
            match.getScorecards().put(userId, PlayerScorecard.builder()
                    .userId(userId)
                    .username(rp.getUser().getUsername())
                    .seatNumber(rp.getSeatNumber())
                    .cumulativeScore(0)
                    .matchStatus(MatchPlayerStatus.ACTIVE)
                    .build());
        }
        match.setStatus(MatchStatus.IN_PROGRESS);
        match.setDealNumber(0);

        persistenceService.recordMatchStart(match.getRoomCode());
        startNewDeal(match);
    }

    private void startNewDeal(MatchState match) {
        turnManager.cancel(match.getRoomCode());
        match.setStatus(MatchStatus.IN_PROGRESS);

        List<Long> activePlayers = match.activeMatchPlayerIds();
        if (activePlayers.size() < 2) {
            Long sole = activePlayers.isEmpty() ? null : activePlayers.get(0);
            finishMatch(match, sole);
            return;
        }

        int dealNo = match.getDealNumber() + 1;
        match.setDealNumber(dealNo);

        Deal deal = new Deal(dealNo);
        deal.getTurnOrder().addAll(activePlayers);
        for (Long userId : activePlayers) {
            deal.getRoundStatus().put(userId, RoundStatus.PLAYING);
            deal.getHasCompletedFirstTurn().put(userId, false);
            deal.getHands().put(userId, new ArrayList<>());
        }

        deal.getClosedDeck().addAll(DeckFactory.buildShuffledDoubleDeck());

        int cardsPerPlayer = match.getConfig().getCardsPerPlayer();
        for (int round = 0; round < cardsPerPlayer; round++) {
            for (Long userId : activePlayers) {
                deal.getHands().get(userId).add(deal.drawFromClosed());
            }
        }

        Card cut = deal.drawFromClosed();
        deal.setCutJokerCard(cut);
        deal.setWildValue(cut.isPrintedJoker() ? Value.ACE : cut.getValue());

        deal.discard(deal.drawFromClosed());

        deal.setCurrentTurnIndex(0);
        deal.setTurnPhase(TurnPhase.AWAITING_DRAW);
        deal.setTurnStartedAt(Instant.now());

        match.setCurrentDeal(deal);
        match.touch();

        broadcastDealState(match, deal, EventType.DEAL_STARTED);
        scheduleTimeoutFor(match);
    }

    private void endDeal(MatchState match, Deal deal, Long winnerUserId, boolean wrongDeclareVoid) {
        turnManager.cancel(match.getRoomCode());
        deal.setStatus(DealStatus.COMPLETED);

        Map<Long, Integer> roundPoints = new LinkedHashMap<>();
        for (Long userId : deal.getTurnOrder()) {
            RoundStatus status = deal.getRoundStatus().get(userId);
            if (status == RoundStatus.DROPPED || status == RoundStatus.DECLARED_WRONG) {
                // Already on the scorecard; surface the same figure in SCORE_UPDATE.
                roundPoints.put(userId, deal.getAppliedRoundPoints().getOrDefault(userId, 0));
                continue;
            }
            if (userId.equals(winnerUserId)) {
                roundPoints.put(userId, 0);
                continue;
            }
            if (wrongDeclareVoid) {
                roundPoints.put(userId, 0); // round voided for everyone else; no fault of theirs
                continue;
            }
            List<Card> hand = deal.getHands().getOrDefault(userId, List.of());
            int points = scoreCalculator.computeLoserPoints(hand, deal.getWildValue(), match.getConfig());
            roundPoints.put(userId, points);
            match.getScorecards().get(userId).addPoints(points);
        }

        List<Long> newlyEliminated = new ArrayList<>();
        if (match.getConfig().getGameVariant().hasElimination()) {
            for (PlayerScorecard scorecard : match.getScorecards().values()) {
                if (scorecard.getMatchStatus() == MatchPlayerStatus.ACTIVE
                        && scorecard.getCumulativeScore() >= match.getConfig().eliminationThreshold()) {
                    scorecard.setMatchStatus(MatchPlayerStatus.ELIMINATED);
                    newlyEliminated.add(scorecard.getUserId());
                }
            }
        }

        broadcastScoreUpdate(match, deal, roundPoints);
        for (Long eliminatedId : newlyEliminated) {
            broadcastService.broadcast(match.getRoomCode(),
                    GameEvent.of(EventType.PLAYER_ELIMINATED).with("userId", eliminatedId));
        }

        List<Long> stillActive = match.activeMatchPlayerIds();

        // DROP left ≤1 PLAYING seat this deal. For pool, POINTS (single-deal),
        // or the final DEALS deal that is a match walkover → MATCH_ENDED.
        // For DEALS with deals still remaining, only the *deal* ends —
        // both seats stay match-ACTIVE and we pause in BETWEEN_DEALS.
        long droppedThisDeal = deal.getTurnOrder().stream()
                .filter(id -> deal.getRoundStatus().get(id) == RoundStatus.DROPPED)
                .count();
        boolean lastStandingThisDeal = !wrongDeclareVoid
                && droppedThisDeal >= 1
                && deal.activePlayerIds().size() <= 1;
        boolean dropWalkover = lastStandingThisDeal && !hasRemainingFixedDeals(match);

        boolean matchComplete = isMatchComplete(match, stillActive, dropWalkover);

        if (matchComplete) {
            Long matchWinner = resolveMatchWinner(match, winnerUserId, wrongDeclareVoid, dropWalkover, stillActive);
            finishMatch(match, matchWinner);
            return;
        }

        enterBetweenDeals(match, deal, winnerUserId, roundPoints, newlyEliminated);
    }

    /** True when this is a fixed-deal variant and more deals are scheduled after the current one. */
    private static boolean hasRemainingFixedDeals(MatchState match) {
        GameVariant variant = match.getConfig().getGameVariant();
        Integer dealsPerMatch = match.getConfig().getDealsPerMatch();
        return variant.isFixedDealMatch()
                && dealsPerMatch != null
                && match.getDealNumber() < dealsPerMatch;
    }

    private boolean isMatchComplete(MatchState match, List<Long> stillActive, boolean dropWalkover) {
        if (dropWalkover || stillActive.size() <= 1) {
            return true;
        }
        GameVariant variant = match.getConfig().getGameVariant();
        // Points Rummy: one deal is the whole match — never BETWEEN_DEALS.
        if (variant.isSingleDealMatch()) {
            return true;
        }
        Integer dealsPerMatch = match.getConfig().getDealsPerMatch();
        return variant.isFixedDealMatch()
                && dealsPerMatch != null
                && match.getDealNumber() >= dealsPerMatch;
    }

    private Long resolveMatchWinner(MatchState match, Long dealWinnerUserId, boolean wrongDeclareVoid,
                                    boolean dropWalkover, List<Long> stillActive) {
        if (dropWalkover) {
            if (dealWinnerUserId != null) {
                return dealWinnerUserId;
            }
            // Every seat dropped/forfeited in the same deal — no stake winner.
            return stillActive.size() == 1 ? stillActive.get(0) : null;
        }
        if (stillActive.size() == 1) {
            return stillActive.get(0);
        }
        if (stillActive.isEmpty()) {
            return null;
        }
        if (wrongDeclareVoid) {
            // Voided final Points/Deals deal with multiple players still active → ABORTED.
            return null;
        }
        // Points / Deals: lowest cumulative score wins.
        return stillActive.stream()
                .min(Comparator
                        .comparingInt((Long id) -> match.getScorecards().get(id).getCumulativeScore())
                        .thenComparingLong(id -> id))
                .orElse(null);
    }

    private void enterBetweenDeals(MatchState match, Deal deal, Long winnerUserId,
                                   Map<Long, Integer> roundPoints, List<Long> newlyEliminated) {
        match.setStatus(MatchStatus.BETWEEN_DEALS);
        match.touch();

        int autoSeconds = match.getConfig().getAutoNextDealSeconds();
        broadcastDealResult(match, deal, winnerUserId, roundPoints, newlyEliminated, false, autoSeconds);
        scheduleNextDeal(match);
    }

    private void scheduleNextDeal(MatchState match) {
        int seconds = Math.max(1, match.getConfig().getAutoNextDealSeconds());
        String roomCode = match.getRoomCode();
        turnManager.schedule(roomCode, seconds, () -> onNextDealTimeout(roomCode));
    }

    private void onNextDealTimeout(String roomCode) {
        MatchState match = gameStateService.get(roomCode);
        if (match == null) {
            return;
        }
        match.getLock().lock();
        try {
            if (match.getStatus() != MatchStatus.BETWEEN_DEALS) {
                return;
            }
            startNewDeal(match);
        } finally {
            match.getLock().unlock();
        }
    }

    private void handleStartNextDeal(MatchState match, Long userId) {
        if (match.getStatus() != MatchStatus.BETWEEN_DEALS) {
            sendError(match.getRoomCode(), userId, "No deal result pending");
            return;
        }
        PlayerScorecard scorecard = match.getScorecards().get(userId);
        if (scorecard == null || scorecard.getMatchStatus() != MatchPlayerStatus.ACTIVE) {
            sendError(match.getRoomCode(), userId, "Only active players can start the next deal");
            return;
        }
        turnManager.cancel(match.getRoomCode());
        startNewDeal(match);
    }

    private void handleLeaveTable(MatchState match, Long userId) {
        if (match.getStatus() == MatchStatus.COMPLETED || match.getStatus() == MatchStatus.WAITING) {
            sendError(match.getRoomCode(), userId, "Leave table is only available during a live match");
            return;
        }
        PlayerScorecard scorecard = match.getScorecards().get(userId);
        if (scorecard == null || scorecard.getMatchStatus() != MatchPlayerStatus.ACTIVE) {
            sendError(match.getRoomCode(), userId, "You are not an active player at this table");
            return;
        }

        if (match.getStatus() == MatchStatus.IN_PROGRESS) {
            leaveDuringActiveDeal(match, userId);
            return;
        }

        // BETWEEN_DEALS: any leave ends the whole match so every remaining
        // client can show Match Summary (no silent continue / auto next deal).
        endMatchAfterVoluntaryLeave(match, userId);
    }

    /**
     * EXIT / Leave during an active deal: forfeit the seat like a disconnect
     * DROP, remove the player from the match, and finish the match when only
     * one (or zero) active seats remain — so heads-up leave ends the game for
     * everyone immediately.
     */
    private void leaveDuringActiveDeal(MatchState match, Long userId) {
        Deal deal = match.getCurrentDeal();
        if (deal != null && deal.getStatus() == DealStatus.IN_PROGRESS
                && deal.getRoundStatus().get(userId) == RoundStatus.PLAYING) {
            forfeitPlayerFromCurrentDeal(match, userId, "left_table");
        }

        if (match.getStatus() == MatchStatus.COMPLETED) {
            return;
        }

        PlayerScorecard scorecard = match.getScorecards().get(userId);
        if (scorecard != null && scorecard.getMatchStatus() == MatchPlayerStatus.ACTIVE) {
            scorecard.setMatchStatus(MatchPlayerStatus.ELIMINATED);
            match.touch();
            broadcastService.broadcast(match.getRoomCode(),
                    GameEvent.of(EventType.PLAYER_ELIMINATED).with("userId", userId).with("reason", "LEFT_TABLE"));
        }

        List<Long> stillActive = match.activeMatchPlayerIds();
        if (stillActive.size() <= 1) {
            turnManager.cancel(match.getRoomCode());
            Deal current = match.getCurrentDeal();
            if (current != null && current.getStatus() == DealStatus.IN_PROGRESS) {
                List<Long> remaining = current.activePlayerIds();
                endDeal(match, current, remaining.isEmpty() ? null : remaining.get(0), false);
            } else if (match.getStatus() != MatchStatus.COMPLETED) {
                finishMatch(match, stillActive.isEmpty() ? null : stillActive.get(0));
            }
        }
    }

    private void endMatchAfterVoluntaryLeave(MatchState match, Long userId) {
        turnManager.cancel(match.getRoomCode());
        PlayerScorecard scorecard = match.getScorecards().get(userId);
        if (scorecard != null) {
            scorecard.setMatchStatus(MatchPlayerStatus.ELIMINATED);
        }
        match.touch();
        broadcastService.broadcast(match.getRoomCode(),
                GameEvent.of(EventType.PLAYER_ELIMINATED).with("userId", userId).with("reason", "LEFT_TABLE"));

        List<Long> stillActive = match.activeMatchPlayerIds();
        Long winner;
        if (stillActive.isEmpty()) {
            winner = null;
        } else if (stillActive.size() == 1) {
            winner = stillActive.get(0);
        } else {
            winner = stillActive.stream()
                    .min(Comparator
                            .comparingInt((Long id) -> match.getScorecards().get(id).getCumulativeScore())
                            .thenComparingLong(id -> id))
                    .orElse(null);
        }
        finishMatch(match, winner);
    }

    private static Integer resolveDealsPerMatch(GameVariant variant, Integer roomDealsPerMatch) {
        if (variant.hasElimination() || variant.isSingleDealMatch()) {
            // Pool: elimination-driven. Points: always one deal (ignore room value).
            return null;
        }
        if (!variant.isFixedDealMatch()) {
            return null;
        }
        if (roomDealsPerMatch != null) {
            return roomDealsPerMatch;
        }
        return GameConfig.DEFAULT_DEALS_PER_MATCH;
    }

    private void finishMatch(MatchState match, Long matchWinnerId) {
        match.setStatus(MatchStatus.COMPLETED);
        match.setMatchWinnerId(matchWinnerId);
        if (matchWinnerId != null && match.getScorecards().containsKey(matchWinnerId)) {
            match.getScorecards().get(matchWinnerId).setMatchStatus(MatchPlayerStatus.WINNER);
        }

        matchSettlementService.settleStakes(new SettleStakesCommand(
                match.getRoomCode(),
                match.getStakeAmount(),
                match.getSeatOrder().size(),
                matchWinnerId));

        Map<Long, Integer> finalScores = new LinkedHashMap<>();
        match.getScorecards().forEach((id, sc) -> finalScores.put(id, sc.getCumulativeScore()));
        persistenceService.recordMatchEnd(match.getRoomCode(), matchWinnerId, finalScores);

        broadcastService.broadcast(match.getRoomCode(), GameEvent.of(EventType.MATCH_ENDED)
                .with("winnerUserId", matchWinnerId)
                .with("finalScores", finalScores)
                .with("dealsPlayed", match.getDealNumber()));

        // The DB row (GameSession/RoomPlayer, flushed async above) is now the
        // durable record of this match; nothing further reads this in-memory
        // MatchState once MATCH_ENDED has gone out, and a room can never
        // rejoin/restart without going through RoomService's WAITING flow
        // again. Evict it so a naturally-completed match doesn't linger in
        // the map for the rest of the process's lifetime (previously only
        // RoomService.disbandRoom ever removed match state).
        gameStateService.remove(match.getRoomCode());
    }

    // ------------------------------------------------------------------
    // Player actions
    // ------------------------------------------------------------------

    private void handleDraw(MatchState match, Deal deal, Long userId, DrawSource source) {
        if (deal.getTurnPhase() != TurnPhase.AWAITING_DRAW) {
            sendError(match.getRoomCode(), userId, "You have already drawn this turn");
            return;
        }
        if (source == null) {
            sendError(match.getRoomCode(), userId, "Missing draw source");
            return;
        }

        Card drawn;
        if (source == DrawSource.OPEN) {
            drawn = deal.drawFromOpen();
        } else {
            replenishClosedDeckIfNeeded(deal);
            drawn = deal.drawFromClosed();
        }
        if (drawn == null) {
            sendError(match.getRoomCode(), userId, "No cards available to draw from that pile");
            return;
        }

        deal.getHands().computeIfAbsent(userId, k -> new ArrayList<>()).add(drawn);
        deal.setTurnPhase(TurnPhase.AWAITING_DISCARD);
        deal.touch();

        persistenceService.recordMove(match.getRoomCode(), userId,
                source == DrawSource.OPEN ? MoveType.DRAW_OPEN : MoveType.DRAW_CLOSED,
                "{}", nextSequence(match.getRoomCode()));

        broadcastDealState(match, deal, EventType.CARD_DRAWN);
    }

    private void handleDiscard(MatchState match, Deal deal, Long userId, String cardCode) {
        if (deal.getTurnPhase() != TurnPhase.AWAITING_DISCARD) {
            sendError(match.getRoomCode(), userId, "Draw a card before discarding");
            return;
        }
        Card card = removeCardByCode(deal.getHands().get(userId), cardCode);
        if (card == null) {
            sendError(match.getRoomCode(), userId, "That card is not in your hand");
            return;
        }

        deal.discard(card);
        deal.getHasCompletedFirstTurn().put(userId, true);

        persistenceService.recordMove(match.getRoomCode(), userId, MoveType.DISCARD,
                "{\"card\":\"" + card.getCode() + "\"}", nextSequence(match.getRoomCode()));

        broadcastDealState(match, deal, EventType.CARD_DISCARDED);
        advanceAfterDiscard(match, deal);
    }

    private void handleDeclare(MatchState match, Deal deal, Long userId, String cardCode) {
        if (deal.getTurnPhase() != TurnPhase.AWAITING_DISCARD) {
            sendError(match.getRoomCode(), userId, "Draw a card before declaring");
            return;
        }
        List<Card> hand = deal.getHands().get(userId);
        Card setAside = removeCardByCode(hand, cardCode);
        if (setAside == null) {
            sendError(match.getRoomCode(), userId, "Specify a valid card to finalize your declare");
            return;
        }

        DeclareResult result = handValidator.validateDeclare(hand, deal.getWildValue());
        deal.discard(setAside);

        // Always reveal the finish card + grouping (including unmatched on wrong show).
        List<Meld> revealMelds = new ArrayList<>(
                result.getMelds() != null ? result.getMelds() : List.of());
        revealMelds.add(new Meld(MeldType.SET_ASIDE, List.of(setAside)));
        DeclareResult broadcastResult = DeclareResult.builder()
                .valid(result.isValid())
                .reason(result.getReason())
                .melds(revealMelds)
                .build();

        persistenceService.recordMove(match.getRoomCode(), userId, MoveType.DECLARE,
                "{\"valid\":" + result.isValid() + "}", nextSequence(match.getRoomCode()));
        broadcastDeclareResult(match, userId, broadcastResult);

        if (result.isValid()) {
            deal.getRoundStatus().put(userId, RoundStatus.DECLARED_VALID);
            deal.setDeclarerUserId(userId);
            endDeal(match, deal, userId, false);
        } else {
            deal.getRoundStatus().put(userId, RoundStatus.DECLARED_WRONG);
            int wrongPoints = scoreCalculator.wrongDeclarePoints(match.getConfig());
            match.getScorecards().get(userId).addPoints(wrongPoints);
            deal.getAppliedRoundPoints().put(userId, wrongPoints);
            endDeal(match, deal, null, true);
        }
    }

    private void handleDrop(MatchState match, Deal deal, Long userId) {
        if (deal.getTurnPhase() != TurnPhase.AWAITING_DRAW) {
            sendError(match.getRoomCode(), userId, "You may only drop before drawing on your turn");
            return;
        }

        boolean isFirstTurn = !deal.getHasCompletedFirstTurn().getOrDefault(userId, false);
        int penalty = isFirstTurn
                ? scoreCalculator.firstDropPoints(match.getConfig())
                : scoreCalculator.middleDropPoints(match.getConfig());

        deal.getRoundStatus().put(userId, RoundStatus.DROPPED);
        match.getScorecards().get(userId).addPoints(penalty);
        deal.getAppliedRoundPoints().put(userId, penalty);

        List<Card> hand = deal.getHands().remove(userId);
        if (hand != null && !hand.isEmpty()) {
            deal.returnCardsToClosedDeckShuffled(hand);
        }

        persistenceService.recordMove(match.getRoomCode(), userId, MoveType.DROP,
                "{\"penalty\":" + penalty + "}", nextSequence(match.getRoomCode()));

        broadcastDealState(match, deal, EventType.PLAYER_DROPPED);

        if (deal.activePlayerCount() <= 1) {
            List<Long> remaining = deal.activePlayerIds();
            endDeal(match, deal, remaining.isEmpty() ? null : remaining.get(0), false);
            return;
        }

        deal.advanceTurn();
        broadcastDealState(match, deal, EventType.TURN_STATE);
        scheduleTimeoutFor(match);
    }

    // ------------------------------------------------------------------
    // Disconnect forfeiture (RoomLifecycleService reaper hook)
    // ------------------------------------------------------------------

    /**
     * Forces a seated player out of the current deal because their
     * WebSocket has been gone longer than the reconnect grace period —
     * called only by the scheduled {@code RoomLifecycleService} reaper,
     * never directly from a client message. Unlike a normal {@code DROP}
     * (which the player can only invoke on their own turn, before
     * drawing), this can happen at any point in the deal: a disconnect
     * doesn't wait for a convenient moment. Reuses the same penalty/
     * hand-return/turn-advance mechanics as {@link #handleDrop} so a
     * forfeited seat behaves identically to a voluntary drop for scoring
     * and match-progression purposes.
     * <p>
     * Also covers {@link MatchStatus#BETWEEN_DEALS}: a disconnect on the
     * result screen ends the match for everyone (same as {@code LEAVE_TABLE}).
     */
    @Override
    public void forfeitDisconnectedPlayer(String roomCode, Long userId) {
        MatchState match = gameStateService.get(roomCode);
        if (match == null) {
            return;
        }
        match.getLock().lock();
        try {
            if (match.getStatus() == MatchStatus.BETWEEN_DEALS) {
                PlayerScorecard scorecard = match.getScorecards().get(userId);
                if (scorecard != null && scorecard.getMatchStatus() == MatchPlayerStatus.ACTIVE) {
                    endMatchAfterVoluntaryLeave(match, userId);
                }
                return;
            }
            if (match.getStatus() != MatchStatus.IN_PROGRESS) {
                return;
            }
            Deal deal = match.getCurrentDeal();
            if (deal == null || deal.getStatus() != DealStatus.IN_PROGRESS) {
                return;
            }
            if (deal.getRoundStatus().get(userId) != RoundStatus.PLAYING) {
                return; // already dropped/declared/not part of this deal — nothing to forfeit
            }
            forfeitPlayerFromCurrentDeal(match, userId, "disconnect_timeout");
        } finally {
            match.getLock().unlock();
        }
    }

    /**
     * Assumes the caller already holds {@code match.getLock()}. Applies a
     * DROP-equivalent forfeit (penalty + hand return + end-deal / advance).
     */
    private void forfeitPlayerFromCurrentDeal(MatchState match, Long userId, String reason) {
        Deal deal = match.getCurrentDeal();
        if (deal == null || deal.getStatus() != DealStatus.IN_PROGRESS) {
            return;
        }
        if (deal.getRoundStatus().get(userId) != RoundStatus.PLAYING) {
            return;
        }

        boolean wasCurrentTurn = userId.equals(deal.currentTurnUserId());
        boolean isFirstTurn = !deal.getHasCompletedFirstTurn().getOrDefault(userId, false);
        int penalty = isFirstTurn
                ? scoreCalculator.firstDropPoints(match.getConfig())
                : scoreCalculator.middleDropPoints(match.getConfig());

        deal.getRoundStatus().put(userId, RoundStatus.DROPPED);
        PlayerScorecard scorecard = match.getScorecards().get(userId);
        if (scorecard != null) {
            scorecard.addPoints(penalty);
        }

        List<Card> hand = deal.getHands().remove(userId);
        if (hand != null && !hand.isEmpty()) {
            deal.returnCardsToClosedDeckShuffled(hand);
        }

        persistenceService.recordMove(match.getRoomCode(), userId, MoveType.DROP,
                "{\"penalty\":" + penalty + ",\"reason\":\"" + reason + "\"}", nextSequence(match.getRoomCode()));

        log.info("Forfeiting player {} in room {} (penalty={}, reason={}, wasCurrentTurn={})",
                userId, match.getRoomCode(), penalty, reason, wasCurrentTurn);

        broadcastDealState(match, deal, EventType.PLAYER_DROPPED);

        if (deal.activePlayerCount() <= 1) {
            List<Long> remaining = deal.activePlayerIds();
            endDeal(match, deal, remaining.isEmpty() ? null : remaining.get(0), false);
            return;
        }

        if (wasCurrentTurn) {
            deal.advanceTurn();
            broadcastDealState(match, deal, EventType.TURN_STATE);
            scheduleTimeoutFor(match);
        }
    }

    // ------------------------------------------------------------------
    // Turn timeout auto-play (Req. 4 placeholder hook)
    // ------------------------------------------------------------------

    private void onTurnTimeout(String roomCode) {
        MatchState match = gameStateService.get(roomCode);
        if (match == null) {
            return;
        }
        match.getLock().lock();
        try {
            Deal deal = match.getCurrentDeal();
            if (deal == null || deal.getStatus() != DealStatus.IN_PROGRESS) {
                return;
            }
            Long userId = deal.currentTurnUserId();
            if (userId == null) {
                return;
            }

            if (deal.getTurnPhase() == TurnPhase.AWAITING_DRAW) {
                replenishClosedDeckIfNeeded(deal);
                Card drawn = deal.drawFromClosed();
                if (drawn != null) {
                    deal.getHands().computeIfAbsent(userId, k -> new ArrayList<>()).add(drawn);
                    deal.setTurnPhase(TurnPhase.AWAITING_DISCARD);
                }
            }

            List<Card> hand = deal.getHands().get(userId);
            if (hand == null || hand.isEmpty()) {
                handleDrop(match, deal, userId);
                return;
            }

            Card toDiscard = pickAutoDiscard(hand, deal.getWildValue());
            hand.remove(toDiscard);
            deal.discard(toDiscard);
            deal.getHasCompletedFirstTurn().put(userId, true);

            persistenceService.recordMove(roomCode, userId, MoveType.DISCARD,
                    "{\"card\":\"" + toDiscard.getCode() + "\",\"auto\":true}", nextSequence(roomCode));

            broadcastDealState(match, deal, EventType.CARD_DISCARDED);
            advanceAfterDiscard(match, deal);
        } finally {
            match.getLock().unlock();
        }
    }

    private Card pickAutoDiscard(List<Card> hand, Value wildValue) {
        GroupingResult grouping = handValidator.computeBestGrouping(hand, wildValue);
        List<Card> candidates = grouping.getLeftoverCards().isEmpty() ? hand : grouping.getLeftoverCards();
        Card best = candidates.get(0);
        int bestValue = HandValidator.deadwoodValue(best, wildValue);
        for (Card c : candidates) {
            int v = HandValidator.deadwoodValue(c, wildValue);
            if (v > bestValue) {
                best = c;
                bestValue = v;
            }
        }
        return best;
    }

    // ------------------------------------------------------------------
    // Shared helpers
    // ------------------------------------------------------------------

    private void advanceAfterDiscard(MatchState match, Deal deal) {
        replenishClosedDeckIfNeeded(deal);
        if (deal.activePlayerCount() <= 1) {
            List<Long> remaining = deal.activePlayerIds();
            endDeal(match, deal, remaining.isEmpty() ? null : remaining.get(0), false);
            return;
        }
        deal.advanceTurn();
        broadcastDealState(match, deal, EventType.TURN_STATE);
        scheduleTimeoutFor(match);
    }

    private void replenishClosedDeckIfNeeded(Deal deal) {
        if (deal.getClosedDeck().isEmpty() && deal.getDiscardPile().size() > 1) {
            deal.reshuffleDiscardIntoClosedDeck();
        }
    }

    private void scheduleTimeoutFor(MatchState match) {
        turnManager.schedule(match.getRoomCode(), match.getConfig().getTurnTimeoutSeconds(),
                () -> onTurnTimeout(match.getRoomCode()));
    }

    private Card removeCardByCode(List<Card> hand, String cardCode) {
        if (hand == null || cardCode == null) {
            return null;
        }
        for (int i = 0; i < hand.size(); i++) {
            if (hand.get(i).getCode().equalsIgnoreCase(cardCode)) {
                return hand.remove(i);
            }
        }
        return null;
    }

    private long nextSequence(String roomCode) {
        return sequenceCounters.computeIfAbsent(roomCode, r -> new AtomicLong()).incrementAndGet();
    }

    private void sendError(String roomCode, Long userId, String message) {
        broadcastService.sendTo(roomCode, userId, GameEvent.of(EventType.ERROR).with("message", message));
    }

    // ------------------------------------------------------------------
    // Outbound event construction (per-recipient hand obfuscation lives here)
    // ------------------------------------------------------------------

    private void broadcastDealState(MatchState match, Deal deal, EventType type) {
        broadcastService.broadcastPersonalized(match.getRoomCode(), viewerId -> buildDealEvent(type, match, deal, viewerId));
    }

    private GameEvent buildDealEvent(EventType type, MatchState match, Deal deal, Long viewerId) {
        return GameEvent.of(type)
                .with("roomCode", match.getRoomCode())
                .with("dealNumber", deal.getDealNumber())
                .with("matchStatus", match.getStatus().name())
                .with("wildValue", deal.getWildValue() != null ? deal.getWildValue().name() : null)
                .with("cutJokerCard", deal.getCutJokerCard() != null ? deal.getCutJokerCard().getCode() : null)
                .with("discardTop", deal.peekDiscardTop() != null ? deal.peekDiscardTop().getCode() : null)
                .with("closedDeckCount", deal.getClosedDeck().size())
                .with("currentTurnUserId", deal.currentTurnUserId())
                .with("turnPhase", deal.getTurnPhase().name())
                .with("players", buildPlayerViews(match, deal, viewerId));
    }

    /**
     * Anti-cheat boundary: the viewer only ever receives their own {@code hand}
     * contents. Every player (including the viewer) exposes {@code handSize}
     * so clients can render opponents' card-backs without knowing their ranks.
     */
    private List<Map<String, Object>> buildPlayerViews(MatchState match, Deal deal, Long viewerId) {
        List<Map<String, Object>> views = new ArrayList<>();
        for (Long userId : match.getSeatOrder()) {
            PlayerScorecard scorecard = match.getScorecards().get(userId);
            List<Card> hand = deal.getHands().get(userId);

            Map<String, Object> view = new LinkedHashMap<>();
            view.put("userId", userId);
            view.put("username", scorecard != null ? scorecard.getUsername() : null);
            view.put("seatNumber", scorecard != null ? scorecard.getSeatNumber() : null);
            view.put("cumulativeScore", scorecard != null ? scorecard.getCumulativeScore() : 0);
            view.put("matchStatus", scorecard != null ? scorecard.getMatchStatus().name() : null);
            RoundStatus roundStatus = deal.getRoundStatus().get(userId);
            view.put("roundStatus", roundStatus != null ? roundStatus.name() : null);
            if (hand != null) {
                view.put("handSize", hand.size());
                if (userId.equals(viewerId)) {
                    view.put("hand", hand.stream().map(Card::getCode).toList());
                }
            }
            views.add(view);
        }
        return views;
    }

    private void broadcastScoreUpdate(MatchState match, Deal deal, Map<Long, Integer> roundPoints) {
        List<Map<String, Object>> table = buildScoreRows(match, roundPoints);
        broadcastService.broadcast(match.getRoomCode(), GameEvent.of(EventType.SCORE_UPDATE)
                .with("dealNumber", deal.getDealNumber())
                .with("scores", table));
    }

    private void broadcastDealResult(MatchState match, Deal deal, Long winnerUserId,
                                     Map<Long, Integer> roundPoints, List<Long> newlyEliminated,
                                     boolean matchComplete, int autoNextDealSeconds) {
        List<Map<String, Object>> table = buildScoreRows(match, roundPoints);
        Integer dealsPerMatch = match.getConfig().getDealsPerMatch();
        broadcastService.broadcast(match.getRoomCode(), GameEvent.of(EventType.DEAL_RESULT)
                .with("dealNumber", deal.getDealNumber())
                .with("dealsPlayed", deal.getDealNumber())
                .with("dealsPerMatch", dealsPerMatch)
                .with("winnerUserId", winnerUserId)
                .with("matchStatus", match.getStatus().name())
                .with("matchComplete", matchComplete)
                .with("scores", table)
                .with("eliminatedUserIds", newlyEliminated)
                .with("autoNextDealSeconds", matchComplete ? 0 : autoNextDealSeconds));
    }

    private List<Map<String, Object>> buildScoreRows(MatchState match, Map<Long, Integer> roundPoints) {
        List<Map<String, Object>> table = new ArrayList<>();
        for (Long userId : match.getSeatOrder()) {
            PlayerScorecard sc = match.getScorecards().get(userId);
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("userId", userId);
            row.put("username", sc.getUsername());
            row.put("roundPoints", roundPoints.getOrDefault(userId, 0));
            row.put("cumulativeScore", sc.getCumulativeScore());
            row.put("matchStatus", sc.getMatchStatus().name());
            table.add(row);
        }
        return table;
    }

    private void broadcastDeclareResult(MatchState match, Long declarerUserId, DeclareResult result) {
        List<Map<String, Object>> melds = new ArrayList<>();
        for (Meld meld : result.getMelds()) {
            Map<String, Object> m = new LinkedHashMap<>();
            MeldType type = meld.getType();
            m.put("type", type.name());
            // UNMATCHED leftover cards are the failed groups. SET_ASIDE is the
            // finish card (informational), not a failed meld.
            boolean ok = type == MeldType.SET_ASIDE || (type != null && type.isLegalGroup());
            m.put("ok", ok);
            m.put("cards", meld.getCards().stream().map(Card::getCode).toList());
            melds.add(m);
        }
        broadcastService.broadcast(match.getRoomCode(), GameEvent.of(EventType.DECLARE_RESULT)
                .with("userId", declarerUserId)
                .with("valid", result.isValid())
                .with("reason", result.getReason())
                .with("melds", melds));
    }
}
