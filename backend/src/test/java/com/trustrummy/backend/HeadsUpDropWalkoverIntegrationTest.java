package com.trustrummy.backend;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Heads-up DROP walkover: with two seated players, when one DROPs the deal
 * (leaving a single PLAYING seat), the match must finish even on POOL_101 —
 * winner gets MATCH_ENDED + stake settlement, room goes COMPLETED.
 */
class HeadsUpDropWalkoverIntegrationTest extends AbstractGameIntegrationTest {

    @Test
    void twoPlayerPoolDropEndsMatchAndSettlesStakes() throws Exception {
        long unique = System.nanoTime();
        Map<String, Object> host = register("poolhost_" + unique);
        Map<String, Object> guest = register("poolguest_" + unique);
        String hostToken = (String) host.get("token");
        String guestToken = (String) guest.get("token");

        deposit(hostToken, new BigDecimal("100.00"));
        deposit(guestToken, new BigDecimal("100.00"));

        // Default createRoom variant is POOL_101 — this is the case that previously
        // started a next deal instead of finishing the match.
        Map<String, Object> room = createRoom(hostToken, new BigDecimal("25.00"));
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

            assertThat(getBalance(hostToken)).isEqualByComparingTo(new BigDecimal("75.00"));
            assertThat(getBalance(guestToken)).isEqualByComparingTo(new BigDecimal("75.00"));

            long currentTurnUserId = ((Number) hostDeal.get("currentTurnUserId")).longValue();
            boolean hostIsFirst = currentTurnUserId == hostUserId;
            TestWsClient firstMover = hostIsFirst ? hostSocket : guestSocket;
            TestWsClient secondMover = hostIsFirst ? guestSocket : hostSocket;
            String loserToken = hostIsFirst ? hostToken : guestToken;
            String winnerToken = hostIsFirst ? guestToken : hostToken;
            long winnerUserId = hostIsFirst ? guestUserId : hostUserId;

            firstMover.send(Map.of("type", "DROP"));
            assertEvent(firstMover, "PLAYER_DROPPED");
            assertEvent(secondMover, "PLAYER_DROPPED");
            assertEvent(firstMover, "SCORE_UPDATE");
            assertEvent(secondMover, "SCORE_UPDATE");

            Map<String, Object> matchEnded = assertEvent(firstMover, "MATCH_ENDED");
            assertEvent(secondMover, "MATCH_ENDED");
            assertThat(((Number) matchEnded.get("winnerUserId")).longValue()).isEqualTo(winnerUserId);

            // No next DEAL_STARTED — match is over.
            assertThat(firstMover.events.poll(400, TimeUnit.MILLISECONDS)).isNull();

            assertThat(getBalance(winnerToken)).isEqualByComparingTo(new BigDecimal("125.00"));
            assertThat(getBalance(loserToken)).isEqualByComparingTo(new BigDecimal("75.00"));
        } finally {
            hostSocket.close();
            guestSocket.close();
        }
    }
}
