package com.trustrummy.backend.playgroups;

import com.trustrummy.backend.game.model.GameType;
import com.trustrummy.backend.game.model.GameVariant;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record StartPlayGroupGameRequest(
        String name,
        @NotNull @Min(2) @Max(6) Integer maxPlayers,
        @NotNull BigDecimal stakeAmount,
        GameType gameType,
        GameVariant gameVariant,
        @Min(1) @Max(50) Integer dealsPerMatch
) {
}
