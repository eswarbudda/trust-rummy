package com.trustrummy.backend;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Diagnostic test: exercises BOTH DRAW_CARD sources (CLOSED = "pack",
 * OPEN = "discard pile") across several consecutive turns, to check a
 * user report that neither draw works and that the match sometimes ends
 * abruptly right after a draw/discard.
 */
class DrawSourceCoverageIntegrationTest extends AbstractGameIntegrationTest {

    @Test
    void bothDrawSourcesWorkAcrossMultipleTurnsWithoutTheMatchEndingEarly() throws Exception {
        long unique = System.nanoTime();
        Map<String, Object> host = register("drawsrchost_" + unique);
        Map<String, Object> guest = register("drawsrcguest_" + unique);
        String hostToken = (String) host.get("token");
        String guestToken = (String) guest.get("token");

        Map<String, Object> room = createRoom(hostToken, BigDecimal.ZERO);
        String roomCode = (String) room.get("roomCode");
        long hostUserId = firstPlayerUserId(room);
        Map<String, Object> joined = joinRoom(guestToken, roomCode);
        long guestUserId = otherPlayerUserId(joined, hostUserId);

        TestWsClient hostSocket = connect(roomCode, hostToken);
        TestWsClient guestSocket = connect(roomCode, guestToken);
        try {
            assertEvent(hostSocket, "ROOM_STATE");
            assertEvent(guestSocket, "ROOM_STATE");

            hostSocket.send(Map.of("type", "START_MATCH"));
            Map<String, Object> hostDeal = assertEvent(hostSocket, "DEAL_STARTED");
            assertEvent(guestSocket, "DEAL_STARTED");

            long currentTurnUserId = ((Number) hostDeal.get("currentTurnUserId")).longValue();
            boolean hostIsFirstMover = currentTurnUserId == hostUserId;
            TestWsClient p1 = hostIsFirstMover ? hostSocket : guestSocket;
            TestWsClient p2 = hostIsFirstMover ? guestSocket : hostSocket;
            long p1Id = hostIsFirstMover ? hostUserId : guestUserId;
            long p2Id = hostIsFirstMover ? guestUserId : hostUserId;

            // Turn 1: player 1 draws from the CLOSED deck ("pack").
            p1.send(Map.of("type", "DRAW_CARD", "source", "CLOSED"));
            Map<String, Object> drawn1 = assertEvent(p1, "CARD_DRAWN");
            assertEvent(p2, "CARD_DRAWN");
            assertThat(drawn1.get("matchStatus")).isEqualTo("IN_PROGRESS");
            String discard1 = firstHandCardFor(drawn1, p1Id);
            assertThat(discard1).as("player 1 should have a card to discard after CLOSED draw").isNotNull();

            p1.send(Map.of("type", "DISCARD_CARD", "cardCode", discard1));
            assertEvent(p1, "CARD_DISCARDED");
            assertEvent(p2, "CARD_DISCARDED");
            Map<String, Object> turn1 = assertEvent(p1, "TURN_STATE");
            assertEvent(p2, "TURN_STATE");
            assertThat(turn1.get("matchStatus")).isEqualTo("IN_PROGRESS");
            assertThat(((Number) turn1.get("currentTurnUserId")).longValue()).isEqualTo(p2Id);

            // Turn 2: player 2 draws from the OPEN discard pile — the exact
            // path the user reports as broken, and which the existing
            // GameWebSocketFlowIntegrationTest never exercises.
            p2.send(Map.of("type", "DRAW_CARD", "source", "OPEN"));
            Map<String, Object> drawn2 = assertEvent(p2, "CARD_DRAWN");
            assertEvent(p1, "CARD_DRAWN");
            assertThat(drawn2.get("matchStatus")).isEqualTo("IN_PROGRESS");
            String discard2 = firstHandCardFor(drawn2, p2Id);
            assertThat(discard2).as("player 2 should have a card to discard after OPEN draw").isNotNull();

            p2.send(Map.of("type", "DISCARD_CARD", "cardCode", discard2));
            assertEvent(p2, "CARD_DISCARDED");
            assertEvent(p1, "CARD_DISCARDED");
            Map<String, Object> turn2 = assertEvent(p2, "TURN_STATE");
            assertEvent(p1, "TURN_STATE");
            assertThat(turn2.get("matchStatus")).isEqualTo("IN_PROGRESS");
            assertThat(((Number) turn2.get("currentTurnUserId")).longValue()).isEqualTo(p1Id);

            // Turn 3: player 1 draws from CLOSED again — confirms the match
            // is still alive and well after a full OPEN-draw round trip.
            p1.send(Map.of("type", "DRAW_CARD", "source", "CLOSED"));
            Map<String, Object> drawn3 = assertEvent(p1, "CARD_DRAWN");
            assertEvent(p2, "CARD_DRAWN");
            assertThat(drawn3.get("matchStatus")).isEqualTo("IN_PROGRESS");

            // Neither player's socket should have seen a MATCH_ENDED or ERROR
            // anywhere in this sequence.
            assertThat(hostSocket.events.stream().anyMatch(e -> "MATCH_ENDED".equals(e.get("type")) || "ERROR".equals(e.get("type")))).isFalse();
            assertThat(guestSocket.events.stream().anyMatch(e -> "MATCH_ENDED".equals(e.get("type")) || "ERROR".equals(e.get("type")))).isFalse();
            assertThat(hostSocket.events.poll(300, TimeUnit.MILLISECONDS)).isNull();
            assertThat(guestSocket.events.poll(300, TimeUnit.MILLISECONDS)).isNull();
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
