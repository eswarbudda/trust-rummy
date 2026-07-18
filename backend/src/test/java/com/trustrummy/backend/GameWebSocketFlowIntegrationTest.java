package com.trustrummy.backend;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Checked-in regression test for the "silent DRAW_CARD / DISCARD_CARD
 * failures" fix (see {@code GameWebSocketHandler}, {@code GameWebSocketService}).
 * This is a JUnit port of the manual two-socket Node.js script used to
 * verify that fix by hand: it drives the exact same sequence — register
 * two real users, create/join a (free-play) room over REST, open two real
 * WebSocket connections to {@code /ws/game/{roomCode}}, run
 * {@code START_MATCH} then a full {@code DRAW_CARD}/{@code DISCARD_CARD}
 * turn cycle for both players, and asserts that out-of-turn and malformed
 * actions now return a visible {@code ERROR} event instead of silently
 * vanishing.
 */
class GameWebSocketFlowIntegrationTest extends AbstractGameIntegrationTest {

    @Test
    void drawAndDiscardRoundTripAcrossBothPlayersWithVisibleErrors() throws Exception {
        long unique = System.nanoTime();
        Map<String, Object> host = register("host_" + unique);
        Map<String, Object> guest = register("guest_" + unique);
        String hostToken = (String) host.get("token");
        String guestToken = (String) guest.get("token");

        // Free-play room: freshly-registered test users start with a zero wallet
        // balance, and this test is about the DRAW_CARD/DISCARD_CARD wire
        // protocol, not stake settlement (that has its own dedicated test).
        Map<String, Object> room = createRoom(hostToken, BigDecimal.ZERO);
        String roomCode = (String) room.get("roomCode");
        long hostUserId = firstPlayerUserId(room);

        Map<String, Object> joined = joinRoom(guestToken, roomCode);
        long guestUserId = otherPlayerUserId(joined, hostUserId);

        TestWsClient hostSocket = connect(roomCode, hostToken);
        TestWsClient guestSocket = connect(roomCode, guestToken);
        try {
            // Both sockets get a ROOM_STATE snapshot immediately on connect.
            assertEvent(hostSocket, "ROOM_STATE");
            assertEvent(guestSocket, "ROOM_STATE");

            hostSocket.send(Map.of("type", "START_MATCH"));
            Map<String, Object> hostDeal = assertEvent(hostSocket, "DEAL_STARTED");
            assertEvent(guestSocket, "DEAL_STARTED");

            long currentTurnUserId = ((Number) hostDeal.get("currentTurnUserId")).longValue();
            boolean hostIsFirstMover = currentTurnUserId == hostUserId;
            TestWsClient firstMover = hostIsFirstMover ? hostSocket : guestSocket;
            TestWsClient secondMover = hostIsFirstMover ? guestSocket : hostSocket;
            long secondMoverUserId = hostIsFirstMover ? guestUserId : hostUserId;

            // --- Out-of-turn action must return a visible ERROR, never silence. ---
            secondMover.send(Map.of("type", "DISCARD_CARD", "cardCode", "AS"));
            Map<String, Object> outOfTurnError = assertEvent(secondMover, "ERROR");
            assertThat(outOfTurnError.get("message")).isEqualTo("It is not your turn");

            // --- Correct player draws, then discards their own first card. ---
            firstMover.send(Map.of("type", "DRAW_CARD", "source", "CLOSED"));
            Map<String, Object> drawnEvent = assertEvent(firstMover, "CARD_DRAWN");
            assertEvent(secondMover, "CARD_DRAWN");

            long firstMoverUserId = hostIsFirstMover ? hostUserId : guestUserId;
            String cardToDiscard = firstHandCardFor(drawnEvent, firstMoverUserId);
            assertThat(cardToDiscard).as("acting player's own hand should be visible in their CARD_DRAWN payload").isNotNull();

            firstMover.send(Map.of("type", "DISCARD_CARD", "cardCode", cardToDiscard));
            assertEvent(firstMover, "CARD_DISCARDED");
            assertEvent(secondMover, "CARD_DISCARDED");
            Map<String, Object> turnStateAfterFirst = assertEvent(firstMover, "TURN_STATE");
            assertEvent(secondMover, "TURN_STATE");
            assertThat(((Number) turnStateAfterFirst.get("currentTurnUserId")).longValue()).isEqualTo(secondMoverUserId);

            // --- Turn passed correctly; the other player draws + discards too. ---
            secondMover.send(Map.of("type", "DRAW_CARD", "source", "CLOSED"));
            Map<String, Object> secondDrawnEvent = assertEvent(secondMover, "CARD_DRAWN");
            assertEvent(firstMover, "CARD_DRAWN");

            String secondCardToDiscard = firstHandCardFor(secondDrawnEvent, secondMoverUserId);
            assertThat(secondCardToDiscard).isNotNull();

            secondMover.send(Map.of("type", "DISCARD_CARD", "cardCode", secondCardToDiscard));
            assertEvent(secondMover, "CARD_DISCARDED");
            assertEvent(firstMover, "CARD_DISCARDED");
            Map<String, Object> turnStateAfterSecond = assertEvent(secondMover, "TURN_STATE");
            assertEvent(firstMover, "TURN_STATE");
            assertThat(((Number) turnStateAfterSecond.get("currentTurnUserId")).longValue()).isEqualTo(firstMoverUserId);

            // --- Malformed payload must also return a visible ERROR, not silence. ---
            firstMover.sendRaw("{not valid json");
            Map<String, Object> malformedError = assertEvent(firstMover, "ERROR");
            assertThat(malformedError.get("message")).isEqualTo("Malformed action payload");
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
