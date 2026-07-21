package com.trustrummy.backend;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Checked-in regression test for wiring {@code GameRoom.stakeAmount}
 * through {@code MatchSettlementService} / {@code WalletService}
 * (see {@code WalletMatchSettlementService}): stakes must be debited from
 * every seated player's wallet the moment a match actually starts, and the
 * whole pot paid to the match winner when it ends — turning the previously
 * display-only {@code stakeAmount} field into a real economic loop.
 */
class StakeSettlementIntegrationTest extends AbstractGameIntegrationTest {

    @Test
    void stakeIsDebitedOnStartAndPaidToWinnerOnFinish() throws Exception {
        long unique = System.nanoTime();
        Map<String, Object> host = register("stakehost_" + unique);
        Map<String, Object> guest = register("stakeguest_" + unique);
        String hostToken = (String) host.get("token");
        String guestToken = (String) guest.get("token");

        deposit(hostToken, new BigDecimal("100.00"));
        deposit(guestToken, new BigDecimal("100.00"));

        // POINTS is a single-deal match: a DROP ends the match immediately and
        // deterministically — ideal for asserting the payout without simulating
        // a full pool or multi-deal Deals match.
        Map<String, Object> room = createRoom(hostToken, new BigDecimal("25.00"), "POINTS");
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

            // Stake is collected from both seats the instant the match starts.
            assertThat(getBalance(hostToken)).isEqualByComparingTo(new BigDecimal("75.00"));
            assertThat(getBalance(guestToken)).isEqualByComparingTo(new BigDecimal("75.00"));

            long currentTurnUserId = ((Number) hostDeal.get("currentTurnUserId")).longValue();
            boolean hostIsFirstMover = currentTurnUserId == hostUserId;
            TestWsClient firstMover = hostIsFirstMover ? hostSocket : guestSocket;
            TestWsClient secondMover = hostIsFirstMover ? guestSocket : hostSocket;
            String loserToken = hostIsFirstMover ? hostToken : guestToken;
            String winnerToken = hostIsFirstMover ? guestToken : hostToken;
            long winnerUserId = hostIsFirstMover ? guestUserId : hostUserId;

            // The player on turn drops before drawing — heads-up DROP on POINTS
            // ends the (single) deal and the match at once.
            firstMover.send(Map.of("type", "DROP"));
            assertEvent(firstMover, "PLAYER_DROPPED");
            assertEvent(secondMover, "PLAYER_DROPPED");
            assertEvent(firstMover, "SCORE_UPDATE");
            assertEvent(secondMover, "SCORE_UPDATE");
            Map<String, Object> matchEnded = assertEvent(firstMover, "MATCH_ENDED");
            assertEvent(secondMover, "MATCH_ENDED");
            assertThat(((Number) matchEnded.get("winnerUserId")).longValue()).isEqualTo(winnerUserId);

            // Winner collects the whole pot (both stakes); loser's stake is gone for good.
            assertThat(getBalance(winnerToken)).isEqualByComparingTo(new BigDecimal("125.00"));
            assertThat(getBalance(loserToken)).isEqualByComparingTo(new BigDecimal("75.00"));
        } finally {
            hostSocket.close();
            guestSocket.close();
        }
    }

    @Test
    void startMatchIsRejectedWhenAPlayerCannotAffordTheStake() throws Exception {
        long unique = System.nanoTime();
        Map<String, Object> host = register("brokehost_" + unique);
        Map<String, Object> guest = register("brokeguest_" + unique);
        String hostToken = (String) host.get("token");
        String guestToken = (String) guest.get("token");
        // Deliberately no deposit — both wallets start at zero.

        Map<String, Object> room = createRoom(hostToken, new BigDecimal("25.00"));
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
            Map<String, Object> error = assertEvent(hostSocket, "ERROR");
            assertThat((String) error.get("message")).contains("does not have enough wallet balance");

            // Rejected before anyone was charged — the other player sees nothing, and no balance moved.
            assertThat(guestSocket.events.poll(500, TimeUnit.MILLISECONDS)).isNull();
            assertThat(getBalance(hostToken)).isEqualByComparingTo(BigDecimal.ZERO);
            assertThat(getBalance(guestToken)).isEqualByComparingTo(BigDecimal.ZERO);
        } finally {
            hostSocket.close();
            guestSocket.close();
        }
    }
}
