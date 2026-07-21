package com.trustrummy.backend.game.model;

/**
 * Supported Rummy match variants.
 * <ul>
 *   <li>{@link #POOL_101} / {@link #POOL_201} — multi-deal until elimination
 *       (cumulative score crosses the threshold).</li>
 *   <li>{@link #POINTS} — traditional single-deal match; ends after one deal
 *       with immediate stake settlement (no {@code BETWEEN_DEALS}).</li>
 *   <li>{@link #DEALS} — fixed-length multi-deal match ({@code dealsPerMatch});
 *       cumulative scoring; settle only after the final deal.</li>
 * </ul>
 */
public enum GameVariant {
    POOL_101(101),
    POOL_201(201),
    POINTS(Integer.MAX_VALUE),
    DEALS(Integer.MAX_VALUE);

    private final int eliminationThreshold;

    GameVariant(int eliminationThreshold) {
        this.eliminationThreshold = eliminationThreshold;
    }

    public int getEliminationThreshold() {
        return eliminationThreshold;
    }

    public boolean hasElimination() {
        return this == POOL_101 || this == POOL_201;
    }

    /** Single-deal match (Points Rummy) — never enters {@code BETWEEN_DEALS}. */
    public boolean isSingleDealMatch() {
        return this == POINTS;
    }

    /** Fixed-length multi-deal match (Deals Rummy), not pool elimination. */
    public boolean isFixedDealMatch() {
        return this == DEALS;
    }
}
