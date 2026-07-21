package com.trustrummy.backend;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Pool 101: once a player's cumulative score reaches 101 they are eliminated;
 * with two seats that must end the match ({@code MATCH_ENDED}), not
 * {@code BETWEEN_DEALS}.
 */
class PoolEliminationIntegrationTest extends AbstractGameIntegrationTest {

    @Test
    void pool101EndsMatchWhenAPlayerReachesEliminationThreshold() throws Exception {
        long unique = System.nanoTime();
        Map<String, Object> host = register("pool101host_" + unique);
        Map<String, Object> guest = register("pool101guest_" + unique);
        String hostToken = (String) host.get("token");
        String guestToken = (String) guest.get("token");

        Map<String, Object> room = createRoom(hostToken, BigDecimal.ZERO, "POOL_101");
        assertThat(room.get("gameVariant")).isEqualTo("POOL_101");
        String roomCode = (String) room.get("roomCode");
        long hostUserId = firstPlayerUserId(room);
        joinRoom(guestToken, roomCode);

        TestWsClient hostSocket = connect(roomCode, hostToken);
        TestWsClient guestSocket = connect(roomCode, guestToken);
        try {
            assertEvent(hostSocket, "ROOM_STATE");
            assertEvent(guestSocket, "ROOM_STATE");

            hostSocket.send(Map.of("type", "START_MATCH"));
            Map<String, Object> deal = assertEvent(hostSocket, "DEAL_STARTED");
            assertEvent(guestSocket, "DEAL_STARTED");

            // Wrong-declare penalty is 80. Two wrong shows by the same player
            // → 160 >= 101 → eliminated → sole remaining seat wins the match.
            Long penalizedUserId = null;
            for (int attempt = 0; attempt < 6; attempt++) {
                long turnUserId = ((Number) deal.get("currentTurnUserId")).longValue();
                TestWsClient actor = turnUserId == hostUserId ? hostSocket : guestSocket;
                TestWsClient other = turnUserId == hostUserId ? guestSocket : hostSocket;

                actor.send(Map.of("type", "DRAW_CARD", "source", "CLOSED"));
                Map<String, Object> drawn = assertEvent(actor, "CARD_DRAWN");
                assertEvent(other, "CARD_DRAWN");

                String card = firstHandCardFor(drawn, turnUserId);
                assertThat(card).isNotNull();
                actor.send(Map.of("type", "DECLARE", "cardCode", card));
                Map<String, Object> declared = assertEvent(actor, "DECLARE_RESULT");
                assertEvent(other, "DECLARE_RESULT");
                assertThat(declared.get("valid")).isEqualTo(false);

                Map<String, Object> score = assertEvent(actor, "SCORE_UPDATE");
                assertEvent(other, "SCORE_UPDATE");
                @SuppressWarnings("unchecked")
                List<Map<String, Object>> scores = (List<Map<String, Object>>) score.get("scores");
                for (Map<String, Object> row : scores) {
                    if (((Number) row.get("userId")).longValue() == turnUserId) {
                        int cumulative = ((Number) row.get("cumulativeScore")).intValue();
                        int roundPts = ((Number) row.get("roundPoints")).intValue();
                        assertThat(roundPts).isEqualTo(80);
                        if (cumulative >= 101) {
                            penalizedUserId = turnUserId;
                            assertThat(row.get("matchStatus")).isEqualTo("ELIMINATED");
                        }
                    }
                }

                Map<String, Object> next = assertOneOf(actor, "MATCH_ENDED", "PLAYER_ELIMINATED", "DEAL_RESULT");
                if ("PLAYER_ELIMINATED".equals(next.get("type"))) {
                    assertEvent(other, "PLAYER_ELIMINATED");
                    next = assertOneOf(actor, "MATCH_ENDED", "DEAL_RESULT");
                }
                assertEvent(other, (String) next.get("type"));

                if ("MATCH_ENDED".equals(next.get("type"))) {
                    assertThat(penalizedUserId).isNotNull();
                    assertThat(next.get("winnerUserId")).isNotNull();
                    assertThat(((Number) next.get("winnerUserId")).longValue()).isNotEqualTo(penalizedUserId);
                    return;
                }

                assertThat(next.get("matchStatus")).isEqualTo("BETWEEN_DEALS");
                actor.send(Map.of("type", "START_NEXT_DEAL"));
                deal = assertEvent(actor, "DEAL_STARTED");
                assertEvent(other, "DEAL_STARTED");
            }
            throw new AssertionError("Expected MATCH_ENDED after a player reached 101 cumulative points");
        } finally {
            hostSocket.close();
            guestSocket.close();
        }
    }

    private Map<String, Object> assertOneOf(TestWsClient client, String... expectedTypes) throws InterruptedException {
        Map<String, Object> event = client.events.poll(5, java.util.concurrent.TimeUnit.SECONDS);
        assertThat(event)
                .as("expected one of %s within 5s but none arrived", Set.of(expectedTypes))
                .isNotNull();
        assertThat(expectedTypes)
                .as("unexpected event type; full payload was: %s", event)
                .contains((String) event.get("type"));
        return event;
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
