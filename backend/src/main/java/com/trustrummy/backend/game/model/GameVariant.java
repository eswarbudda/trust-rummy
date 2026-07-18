package com.trustrummy.backend.game.model;

/**
 * Supported Rummy match variants. Pool variants eliminate a player once
 * their cumulative score crosses the variant's threshold; classic points
 * rummy has no elimination (each deal is scored independently).
 */
public enum GameVariant {
    POOL_101(101),
    POOL_201(201),
    POINTS(Integer.MAX_VALUE);

    private final int eliminationThreshold;

    GameVariant(int eliminationThreshold) {
        this.eliminationThreshold = eliminationThreshold;
    }

    public int getEliminationThreshold() {
        return eliminationThreshold;
    }

    public boolean hasElimination() {
        return this != POINTS;
    }
}
