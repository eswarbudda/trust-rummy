package com.trustrummy.backend.service.settlement;

/**
 * Outcome of {@link MatchSettlementService#collectStakes}. The game engine
 * owns WebSocket error delivery — settlement only reports success / failure text.
 */
public record CollectStakesResult(boolean success, String errorMessage) {

    public static CollectStakesResult ok() {
        return new CollectStakesResult(true, null);
    }

    public static CollectStakesResult failed(String errorMessage) {
        return new CollectStakesResult(false, errorMessage);
    }
}
