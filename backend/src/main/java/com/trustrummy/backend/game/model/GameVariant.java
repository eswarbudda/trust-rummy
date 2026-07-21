package com.trustrummy.backend.game.model;

/**
 * Supported Rummy match variants. Pool variants eliminate a player once
 * their cumulative score crosses the variant's threshold; Points and Deals
 * rummy have no elimination — the match ends after {@code dealsPerMatch}
 * deals (or when only one active player remains).
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

    /** Fixed-length multi-deal match (Points / Deals), not pool elimination. */
    public boolean isFixedDealMatch() {
        return this == POINTS || this == DEALS;
    }
}
