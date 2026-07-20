package com.trustrummy.backend.service.settlement;

import java.math.BigDecimal;

/**
 * Inputs for winner-takes-all pot payout at match end.
 * {@code seatCount} is the number of players who paid stake at collect time
 * (historically {@code MatchState.seatOrder.size()}).
 */
public record SettleStakesCommand(
        String roomCode,
        BigDecimal stakeAmount,
        int seatCount,
        Long winnerUserId
) {
}
