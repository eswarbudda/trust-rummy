package com.trustrummy.backend.game.config;

import com.trustrummy.backend.game.model.GameVariant;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * Per-room configurable rule set. One immutable instance is attached to a
 * {@code MatchState} at match start and referenced by every deal within
 * that match.
 */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GameConfig {

    public static final int DEFAULT_POINTS_DEALS_PER_MATCH = 2;
    public static final int DEFAULT_AUTO_NEXT_DEAL_SECONDS = 10;

    @Builder.Default
    private int maxPlayers = 6;

    @Builder.Default
    private GameVariant gameVariant = GameVariant.POOL_101;

    @Builder.Default
    private int penaltyFirstDrop = 20;

    @Builder.Default
    private int penaltyMiddleDrop = 40;

    @Builder.Default
    private int penaltyMaxCap = 80;

    @Builder.Default
    private int penaltyWrongDeclare = 80;

    @Builder.Default
    private int cardsPerPlayer = 13;

    @Builder.Default
    private int turnTimeoutSeconds = 30;

    /**
     * How many deals make up a Points/Deals match. {@code null} for pool
     * variants (match ends via elimination). POINTS defaults to
     * {@link #DEFAULT_POINTS_DEALS_PER_MATCH} when the room omits it.
     */
    private Integer dealsPerMatch;

    @Builder.Default
    private int autoNextDealSeconds = DEFAULT_AUTO_NEXT_DEAL_SECONDS;

    public int eliminationThreshold() {
        return gameVariant.getEliminationThreshold();
    }

    public static GameConfig defaults() {
        return GameConfig.builder().build();
    }
}
