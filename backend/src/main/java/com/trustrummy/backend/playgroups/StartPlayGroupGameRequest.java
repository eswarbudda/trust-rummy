package com.trustrummy.backend.playgroups;

import com.trustrummy.backend.game.model.GameType;
import com.trustrummy.backend.game.model.GameVariant;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

/**
 * Start-game payload for a play group. Seat capacity is derived server-side
 * from active member count (capped at 6) — clients do not send maxPlayers.
 */
public record StartPlayGroupGameRequest(
        String name,
        @NotNull BigDecimal stakeAmount,
        GameType gameType,
        GameVariant gameVariant,
        @Min(1) @Max(50) Integer dealsPerMatch
) {
}
