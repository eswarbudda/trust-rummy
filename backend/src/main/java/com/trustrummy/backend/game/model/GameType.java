package com.trustrummy.backend.game.model;

/**
 * Top-level discriminator for which game a room plays. Only {@link #RUMMY}
 * has a real {@code GameEngine} implementation today; the other values are
 * reserved so a room's persisted game type won't need another migration
 * once they land. {@code GameVariant} remains the sub-variant selector
 * specifically for {@link #RUMMY} (POOL_101/POOL_201/POINTS).
 */
public enum GameType {
    RUMMY,
    ANDAR_BAHAR,
    TEEN_PATTI
}
