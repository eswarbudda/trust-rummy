package com.trustrummy.backend;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * EXIT / LEAVE_TABLE during a live heads-up deal must end the match for
 * both seats (MATCH_ENDED), not leave the opponent playing alone.
 */
class LeaveTableEndsMatchIntegrationTest extends AbstractGameIntegrationTest {

    @Test
    void leaveTableDuringActiveHeadsUpDealEndsMatchForBoth() throws Exception {
        long unique = System.nanoTime();
        Map<String, Object> host = register("leavehost_" + unique);
        Map<String, Object> guest = register("leaveguest_" + unique);
        String hostToken = (String) host.get("token");
        String guestToken = (String) guest.get("token");

        deposit(hostToken, new BigDecimal("100.00"));
        deposit(guestToken, new BigDecimal("100.00"));

        Map<String, Object> room = createRoom(hostToken, new BigDecimal("10.00"));
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
            TestWsClient leaver = currentTurnUserId == hostUserId ? hostSocket : guestSocket;
            TestWsClient stayer = currentTurnUserId == hostUserId ? guestSocket : hostSocket;
            long winnerUserId = currentTurnUserId == hostUserId ? guestUserId : hostUserId;

            // Leave on your turn mid-deal (forfeit) — must MATCH_ENDED for both.
            leaver.send(Map.of("type", "LEAVE_TABLE"));
            assertEvent(leaver, "PLAYER_DROPPED");
            assertEvent(stayer, "PLAYER_DROPPED");
            assertEvent(leaver, "SCORE_UPDATE");
            assertEvent(stayer, "SCORE_UPDATE");

            Map<String, Object> matchEnded = assertEvent(leaver, "MATCH_ENDED");
            assertEvent(stayer, "MATCH_ENDED");
            assertThat(((Number) matchEnded.get("winnerUserId")).longValue()).isEqualTo(winnerUserId);
        } finally {
            hostSocket.close();
            guestSocket.close();
        }
    }
}
