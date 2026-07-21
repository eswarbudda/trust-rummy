package com.trustrummy.backend;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Result-state flow: after a deal ends with players remaining, the engine
 * must pause in {@code BETWEEN_DEALS}, emit {@code DEAL_RESULT}, reject
 * gameplay actions, and only start the next deal on {@code START_NEXT_DEAL}
 * (or the auto countdown — covered implicitly by the engine schedule).
 */
class DealResultStateIntegrationTest extends AbstractGameIntegrationTest {

    @Test
    void poolDealPausesWithDealResultUntilStartNextDeal() throws Exception {
        long unique = System.nanoTime();
        Map<String, Object> host = register("result_host_" + unique);
        Map<String, Object> guest = register("result_guest_" + unique);
        String hostToken = (String) host.get("token");
        String guestToken = (String) guest.get("token");

        // Free-play POOL_101: force a deal end via DROP without ending the match
        // (3 seats would be needed for drop without heads-up walkover — use
        // POINTS with dealsPerMatch=2 and a wrong declare to void deal 1).
        Map<String, Object> room = createRoom(hostToken, BigDecimal.ZERO, "POINTS", 2);
        String roomCode = (String) room.get("roomCode");
        long hostUserId = firstPlayerUserId(room);
        Map<String, Object> joined = joinRoom(guestToken, roomCode);
        otherPlayerUserId(joined, hostUserId);

        TestWsClient hostSocket = connect(roomCode, hostToken);
        TestWsClient guestSocket = connect(roomCode, guestToken);
        try {
            assertEvent(hostSocket, "ROOM_STATE");
            assertEvent(guestSocket, "ROOM_STATE");

            hostSocket.send(Map.of("type", "START_MATCH"));
            Map<String, Object> hostDeal = assertEvent(hostSocket, "DEAL_STARTED");
            assertEvent(guestSocket, "DEAL_STARTED");

            long currentTurnUserId = ((Number) hostDeal.get("currentTurnUserId")).longValue();
            long firstMoverUserId = currentTurnUserId;
            TestWsClient firstMover = currentTurnUserId == hostUserId ? hostSocket : guestSocket;
            TestWsClient secondMover = currentTurnUserId == hostUserId ? guestSocket : hostSocket;

            firstMover.send(Map.of("type", "DRAW_CARD", "source", "CLOSED"));
            Map<String, Object> drawnEvent = assertEvent(firstMover, "CARD_DRAWN");
            assertEvent(secondMover, "CARD_DRAWN");

            String cardToSetAside = firstHandCardFor(drawnEvent, firstMoverUserId);
            assertThat(cardToSetAside).isNotNull();

            firstMover.send(Map.of("type", "DECLARE", "cardCode", cardToSetAside));
            assertEvent(firstMover, "DECLARE_RESULT");
            assertEvent(secondMover, "DECLARE_RESULT");
            assertEvent(firstMover, "SCORE_UPDATE");
            assertEvent(secondMover, "SCORE_UPDATE");

            Map<String, Object> dealResult = assertEvent(firstMover, "DEAL_RESULT");
            assertEvent(secondMover, "DEAL_RESULT");
            assertThat(dealResult.get("matchStatus")).isEqualTo("BETWEEN_DEALS");
            assertThat(dealResult.get("matchComplete")).isEqualTo(false);
            assertThat(((Number) dealResult.get("autoNextDealSeconds")).intValue()).isEqualTo(10);
            assertThat(((Number) dealResult.get("dealNumber")).intValue()).isEqualTo(1);

            // No immediate next deal.
            assertThat(firstMover.events.poll(400, TimeUnit.MILLISECONDS)).isNull();

            // Gameplay actions rejected while BETWEEN_DEALS.
            firstMover.send(Map.of("type", "DRAW_CARD", "source", "CLOSED"));
            Map<String, Object> error = assertEvent(firstMover, "ERROR");
            assertThat((String) error.get("message")).contains("Deal result");

            firstMover.send(Map.of("type", "START_NEXT_DEAL"));
            Map<String, Object> nextDeal = assertEvent(firstMover, "DEAL_STARTED");
            assertEvent(secondMover, "DEAL_STARTED");
            assertThat(((Number) nextDeal.get("dealNumber")).intValue()).isEqualTo(2);
            assertThat(nextDeal.get("matchStatus")).isEqualTo("IN_PROGRESS");
        } finally {
            hostSocket.close();
            guestSocket.close();
        }
    }

    @SuppressWarnings("unchecked")
    private String firstHandCardFor(Map<String, Object> dealEvent, long userId) {
        List<Map<String, Object>> players = (List<Map<String, Object>>) dealEvent.get("players");
        for (Map<String, Object> p : players) {
            if (((Number) p.get("userId")).longValue() == userId) {
                List<String> hand = (List<String>) p.get("hand");
                return hand == null || hand.isEmpty() ? null : hand.get(0);
            }
        }
        return null;
    }
}
