package com.trustrummy.backend;

import com.trustrummy.backend.service.GameStateService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Checked-in regression test for "gap 3" of the Project Health Summary
 * audit: a match's in-memory {@code MatchState} used to linger in
 * {@link GameStateService} forever once it finished (only a
 * disbanded/cancelled room ever removed it), and every match end was
 * recorded as {@code SessionStatus.COMPLETED} even when nobody actually
 * won — making an abandoned match indistinguishable from a cleanly
 * declared one. See {@code RummyEngineService.finishMatch} and
 * {@code GamePersistenceService.recordMatchEnd}.
 */
class MatchLifecycleCleanupIntegrationTest extends AbstractGameIntegrationTest {

    @Autowired
    private GameStateService gameStateService;

    @Test
    void matchStateIsEvictedFromMemoryOnceANaturalWinnerIsDecided() throws Exception {
        long unique = System.nanoTime();
        Map<String, Object> host = register("lifecyclehost_" + unique);
        Map<String, Object> guest = register("lifecycleguest_" + unique);
        String hostToken = (String) host.get("token");
        String guestToken = (String) guest.get("token");

        // POINTS is a single-deal match + free play: a DROP ends the match at
        // once (heads-up walkover), without needing stake bookkeeping (already
        // covered by StakeSettlementIntegrationTest).
        Map<String, Object> room = createRoom(hostToken, BigDecimal.ZERO, "POINTS");
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

            // While the match is live, its state must actually exist in memory.
            assertThat(gameStateService.exists(roomCode)).isTrue();

            long currentTurnUserId = ((Number) hostDeal.get("currentTurnUserId")).longValue();
            TestWsClient firstMover = currentTurnUserId == hostUserId ? hostSocket : guestSocket;
            TestWsClient secondMover = currentTurnUserId == hostUserId ? guestSocket : hostSocket;

            firstMover.send(Map.of("type", "DROP"));
            assertEvent(firstMover, "PLAYER_DROPPED");
            assertEvent(secondMover, "PLAYER_DROPPED");
            assertEvent(firstMover, "SCORE_UPDATE");
            assertEvent(secondMover, "SCORE_UPDATE");
            Map<String, Object> matchEnded = assertEvent(firstMover, "MATCH_ENDED");
            assertEvent(secondMover, "MATCH_ENDED");
            assertThat(matchEnded.get("winnerUserId")).isNotNull();

            // The moment MATCH_ENDED has gone out, the in-memory state for
            // this room must be gone — not merely stale/COMPLETED, but
            // actually removed from the registry.
            assertThat(gameStateService.exists(roomCode)).isFalse();
            assertThat(gameStateService.get(roomCode)).isNull();

            String status = pollMatchStatus(hostToken, roomCode);
            assertThat(status).isEqualTo("COMPLETED");
        } finally {
            hostSocket.close();
            guestSocket.close();
        }
    }

    @Test
    void wrongDeclareThatVoidsTheRoundIsRecordedAsAbortedNotCompleted() throws Exception {
        long unique = System.nanoTime();
        Map<String, Object> host = register("abortedhost_" + unique);
        Map<String, Object> guest = register("abortedguest_" + unique);
        String hostToken = (String) host.get("token");
        String guestToken = (String) guest.get("token");

        // POINTS is a single-deal match: a wrong DECLARE voids the round (no
        // winner) and ends the match immediately with matchWinnerId == null —
        // the exact case that used to be recorded as COMPLETED indistinguishably
        // from a real win. dealsPerMatch on create is ignored for POINTS.
        Map<String, Object> room = createRoom(hostToken, BigDecimal.ZERO, "POINTS");
        assertThat(room.get("dealsPerMatch")).isNull();
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

            // A freshly-dealt-plus-one-drawn 14-card hand is never a valid
            // rummy hand by chance, so declaring with any card set aside is
            // guaranteed to be rejected as a wrong show.
            String cardToSetAside = firstHandCardFor(drawnEvent, firstMoverUserId);
            assertThat(cardToSetAside).isNotNull();

            firstMover.send(Map.of("type", "DECLARE", "cardCode", cardToSetAside));
            Map<String, Object> declareResult = assertEvent(firstMover, "DECLARE_RESULT");
            assertEvent(secondMover, "DECLARE_RESULT");
            assertThat(declareResult.get("valid")).isEqualTo(false);

            assertEvent(firstMover, "SCORE_UPDATE");
            assertEvent(secondMover, "SCORE_UPDATE");
            Map<String, Object> matchEnded = assertEvent(firstMover, "MATCH_ENDED");
            assertEvent(secondMover, "MATCH_ENDED");
            assertThat(matchEnded.get("winnerUserId")).isNull();

            assertThat(gameStateService.exists(roomCode)).isFalse();

            String status = pollMatchStatus(hostToken, roomCode);
            assertThat(status).isEqualTo("ABORTED");
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

    /**
     * {@code recordMatchStart}/{@code recordMatchEnd} are both {@code @Async},
     * so the row is visible with status {@code ACTIVE} (written by
     * recordMatchStart) well before recordMatchEnd's update lands — poll
     * until the status actually reaches a terminal value instead of
     * returning on the first sighting of the row.
     */
    @SuppressWarnings("unchecked")
    private String pollMatchStatus(String jwt, String roomCode) throws InterruptedException {
        String lastSeenStatus = null;
        for (int attempt = 0; attempt < 20; attempt++) {
            HttpEntity<Void> entity = new HttpEntity<>(authHeaders(jwt));
            ResponseEntity<Map> response = rest.exchange(
                    baseUrl("/api/v1/history/matches?page=0&size=10"), HttpMethod.GET, entity, Map.class);
            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
            Map<String, Object> body = response.getBody();
            List<Map<String, Object>> content = (List<Map<String, Object>>) body.get("content");
            for (Map<String, Object> item : content) {
                if (roomCode.equals(item.get("roomCode"))) {
                    lastSeenStatus = (String) item.get("status");
                    if (!"ACTIVE".equals(lastSeenStatus)) {
                        return lastSeenStatus;
                    }
                }
            }
            TimeUnit.MILLISECONDS.sleep(250);
        }
        throw new AssertionError("Match for room " + roomCode
                + " never reached a terminal status in /history/matches; last seen: " + lastSeenStatus);
    }
}
