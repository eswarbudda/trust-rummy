package com.trustrummy.backend.service;

import com.trustrummy.backend.entity.GameRoom;
import com.trustrummy.backend.entity.RoomStatus;
import com.trustrummy.backend.game.model.DealStatus;
import com.trustrummy.backend.game.model.MatchStatus;
import com.trustrummy.backend.game.model.RoundStatus;
import com.trustrummy.backend.game.state.Deal;
import com.trustrummy.backend.game.state.MatchState;
import com.trustrummy.backend.game.ws.GameBroadcastService;
import com.trustrummy.backend.repository.GameRoomRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.List;

/**
 * Periodic reaper that closes the two "the gameplay loop can otherwise
 * never resolve" gaps that nothing else in the engine has a trigger for:
 * <ol>
 *   <li>a lobby room stuck in {@link RoomStatus#WAITING} with nobody
 *       around to start or cancel it — it would otherwise sit forever;</li>
 *   <li>a seated player whose WebSocket has been gone for longer than a
 *       reasonable reconnect window during an active deal. Without this,
 *       the turn-timeout auto-play ({@code RummyEngineService.onTurnTimeout})
 *       only ever kicks in once it becomes that player's turn, and even
 *       then it just keeps auto-playing on their behalf forever instead of
 *       ever freeing the seat — so the other player(s) could be stuck
 *       playing against an empty chair indefinitely.</li>
 * </ol>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RoomLifecycleService {

    private final GameRoomRepository gameRoomRepository;
    private final RoomService roomService;
    private final GameStateService gameStateService;
    private final GameBroadcastService broadcastService;
    private final GameEngineRegistry gameEngineRegistry;

    @Value("${rummy.lifecycle.stale-waiting-room-minutes:30}")
    private long staleWaitingRoomMinutes;

    @Value("${rummy.lifecycle.disconnect-grace-seconds:90}")
    private long disconnectGraceSeconds;

    @Scheduled(fixedRateString = "${rummy.lifecycle.sweep-interval-ms:60000}")
    public void sweep() {
        try {
            sweepStaleWaitingRooms();
        } catch (Exception ex) {
            log.error("Room lifecycle sweep: stale-room pass failed", ex);
        }
        try {
            sweepDisconnectedPlayers();
        } catch (Exception ex) {
            log.error("Room lifecycle sweep: disconnected-player pass failed", ex);
        }
    }

    private void sweepStaleWaitingRooms() {
        Instant cutoff = Instant.now().minus(Duration.ofMinutes(staleWaitingRoomMinutes));
        for (GameRoom room : gameRoomRepository.findByStatus(RoomStatus.WAITING)) {
            Instant lastActivity = room.getUpdatedAt() != null ? room.getUpdatedAt() : room.getCreatedAt();
            if (lastActivity != null && lastActivity.isBefore(cutoff)) {
                log.info("Auto-cancelling stale WAITING room {} (idle since {})", room.getRoomCode(), lastActivity);
                roomService.autoCancelStaleRoom(room);
            }
        }
    }

    private void sweepDisconnectedPlayers() {
        Instant cutoff = Instant.now().minus(Duration.ofSeconds(disconnectGraceSeconds));
        for (MatchState match : gameStateService.activeRooms()) {
            MatchStatus status = match.getStatus();
            if (status != MatchStatus.IN_PROGRESS && status != MatchStatus.BETWEEN_DEALS) {
                continue;
            }

            if (status == MatchStatus.BETWEEN_DEALS) {
                for (Long userId : List.copyOf(match.getSeatOrder())) {
                    if (match.getStatus() != MatchStatus.BETWEEN_DEALS) {
                        break;
                    }
                    Instant disconnectedAt = broadcastService.disconnectedSince(match.getRoomCode(), userId).orElse(null);
                    if (disconnectedAt != null && disconnectedAt.isBefore(cutoff)) {
                        log.info("Ending match for disconnected player {} in room {} during BETWEEN_DEALS",
                                userId, match.getRoomCode());
                        gameEngineRegistry.resolveForRoom(match.getRoomCode())
                                .forfeitDisconnectedPlayer(match.getRoomCode(), userId);
                    }
                }
                continue;
            }

            Deal deal = match.getCurrentDeal();
            if (deal == null || deal.getStatus() != DealStatus.IN_PROGRESS) {
                continue;
            }
            // Snapshot the turn order before iterating: forfeiting a player
            // can end the deal (and clear currentDeal) mid-loop.
            for (Long userId : List.copyOf(deal.getTurnOrder())) {
                if (match.getCurrentDeal() != deal) {
                    break; // the deal already ended from an earlier forfeit this pass
                }
                if (deal.getRoundStatus().get(userId) != RoundStatus.PLAYING) {
                    continue;
                }
                Instant disconnectedAt = broadcastService.disconnectedSince(match.getRoomCode(), userId).orElse(null);
                if (disconnectedAt != null && disconnectedAt.isBefore(cutoff)) {
                    log.info("Forfeiting disconnected player {} in room {} (disconnected since {})",
                            userId, match.getRoomCode(), disconnectedAt);
                    gameEngineRegistry.resolveForRoom(match.getRoomCode()).forfeitDisconnectedPlayer(match.getRoomCode(), userId);
                }
            }
        }
    }
}
