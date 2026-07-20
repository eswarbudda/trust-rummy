package com.trustrummy.backend.service.settlement;

/**
 * Match-level stake collection and prize distribution, isolated from the
 * game engine so alternate backends (Kafka events, external wallets,
 * tournament pots) can replace the default wallet ledger without changing
 * gameplay code.
 */
public interface MatchSettlementService {

    /**
     * Validates balances, debits every seated player, and refunds already-debited
     * seats if a mid-collection debit fails. Free-play ({@code stakeAmount <= 0})
     * is a no-op success.
     */
    CollectStakesResult collectStakes(CollectStakesCommand command);

    /**
     * Pays the pot ({@code stake × seatCount}) to the winner. Free-play and
     * null-winner matches are no-ops (null winner does not refund the pot).
     */
    void settleStakes(SettleStakesCommand command);
}
