package com.trustrummy.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ScorecardSummaryResponse {
    private int totalMatches;
    private int wins;
    private int losses;
    /**
     * Projected chip swing across completed matches, assuming the winner takes
     * every other seated player's stake. This is a heuristic, NOT a read of an
     * actual wallet ledger — match stakes aren't debited/paid out to
     * {@code WalletTransaction} rows yet (see {@code WalletTransactionType}
     * doc), so it may drift from the true wallet balance once that lands.
     */
    private BigDecimal netChips;
    /** Lowest (best) single-deal score across all completed matches; null if none. */
    private Integer bestDealScore;
}
