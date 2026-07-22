package com.trustrummy.backend;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * DEALS (default 2 deals): a heads-up DROP ends only the current deal.
 * The match must pause in {@code BETWEEN_DEALS} so players can start deal 2 —
 * not {@code MATCH_ENDED} (that walkover is for pool / final deal only).
 */
class DealsDropContinuesMatchIntegrationTest extends AbstractGameIntegrationTest {

    @Test
    void dealsHeadsUpDropEntersBetweenDealsThenStartNextDeal() throws Exception {
        long unique = System.nanoTime();
        Map<String, Object> host = register("dealshost_" + unique);
        Map<String, Object> guest = register("dealsguest_" + unique);
        String hostToken = (String) host.get("token");
        String guestToken = (String) guest.get("token");

        Map<String, Object> room = createRoom(hostToken, BigDecimal.ZERO, "DEALS", 2);
        assertThat(room.get("gameVariant")).isEqualTo("DEALS");
        String roomCode = (String) room.get("roomCode");
        long hostUserId = firstPlayerUserId(room);
        joinRoom(guestToken, roomCode);

        TestWsClient hostSocket = connect(roomCode, hostToken);
        TestWsClient guestSocket = connect(roomCode, guestToken);
        try {
            assertEvent(hostSocket, "ROOM_STATE");
            assertEvent(guestSocket, "ROOM_STATE");

            hostSocket.send(Map.of("type", "START_MATCH"));
            Map<String, Object> hostDeal = assertEvent(hostSocket, "DEAL_STARTED");
            assertEvent(guestSocket, "DEAL_STARTED");
            assertThat(((Number) hostDeal.get("dealNumber")).intValue()).isEqualTo(1);

            long turnUserId = ((Number) hostDeal.get("currentTurnUserId")).longValue();
            TestWsClient dropper = turnUserId == hostUserId ? hostSocket : guestSocket;
            TestWsClient other = turnUserId == hostUserId ? guestSocket : hostSocket;

            dropper.send(Map.of("type", "DROP"));
            assertEvent(dropper, "PLAYER_DROPPED");
            assertEvent(other, "PLAYER_DROPPED");
            assertEvent(dropper, "SCORE_UPDATE");
            assertEvent(other, "SCORE_UPDATE");

            Map<String, Object> dealResult = assertEvent(dropper, "DEAL_RESULT");
            assertEvent(other, "DEAL_RESULT");
            assertThat(dealResult.get("matchStatus")).isEqualTo("BETWEEN_DEALS");
            assertThat(dealResult.get("matchComplete")).isEqualTo(false);
            assertThat(((Number) dealResult.get("dealNumber")).intValue()).isEqualTo(1);
            assertThat(((Number) dealResult.get("dealsPerMatch")).intValue()).isEqualTo(2);

            dropper.send(Map.of("type", "START_NEXT_DEAL"));
            Map<String, Object> deal2 = assertEvent(dropper, "DEAL_STARTED");
            assertEvent(other, "DEAL_STARTED");
            assertThat(((Number) deal2.get("dealNumber")).intValue()).isEqualTo(2);
            assertThat(deal2.get("matchStatus")).isEqualTo("IN_PROGRESS");

            @SuppressWarnings("unchecked")
            List<Map<String, Object>> players = (List<Map<String, Object>>) deal2.get("players");
            assertThat(players).hasSize(2);
        } finally {
            hostSocket.close();
            guestSocket.close();
        }
    }
}
