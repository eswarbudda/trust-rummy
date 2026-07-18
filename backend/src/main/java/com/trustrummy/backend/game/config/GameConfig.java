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

    public int eliminationThreshold() {
        return gameVariant.getEliminationThreshold();
    }

    public static GameConfig defaults() {
        return GameConfig.builder().build();
    }
}
