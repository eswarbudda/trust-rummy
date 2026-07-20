package com.trustrummy.backend.service.settlement;

import java.math.BigDecimal;
import java.util.List;

/**
 * Inputs for all-or-nothing stake collection at match start.
 */
public record CollectStakesCommand(
        String roomCode,
        BigDecimal stakeAmount,
        List<SeatedPlayer> seatedPlayers
) {
}
