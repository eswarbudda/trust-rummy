package com.trustrummy.backend.dto;

import com.trustrummy.backend.entity.RoomVisibility;
import com.trustrummy.backend.game.model.GameType;
import com.trustrummy.backend.game.model.GameVariant;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
public class RoomCreateRequest {

    private String name;

    @NotNull
    @Min(2)
    @Max(6)
    private Integer maxPlayers;

    @NotNull
    private BigDecimal stakeAmount;

    /** Defaults to RUMMY if omitted. */
    private GameType gameType;

    /** Defaults to POOL_101 if omitted. */
    private GameVariant gameVariant;

    /**
     * Deals in a {@link GameVariant#DEALS} match only.
     * Ignored for {@link GameVariant#POINTS} (always one deal) and pool variants.
     * DEALS defaults to 2 when omitted.
     */
    @Min(1)
    @Max(50)
    private Integer dealsPerMatch;

    /**
     * Defaults to {@link RoomVisibility#PUBLIC}.
     * HTTP creates may use PUBLIC or PRIVATE; {@link RoomVisibility#GROUP_ONLY}
     * is reserved for play-group start via {@code RoomPort}.
     */
    private RoomVisibility visibility;

    /** Required when visibility is {@link RoomVisibility#GROUP_ONLY}. */
    private Long sourceGroupId;
}
