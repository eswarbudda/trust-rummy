package com.trustrummy.backend.rooms;

import com.trustrummy.backend.entity.RoomVisibility;
import com.trustrummy.backend.game.model.GameType;
import com.trustrummy.backend.game.model.GameVariant;

import java.math.BigDecimal;

/**
 * Portable create-room command for social modules (Play Groups, Invitations).
 */
public record CreateWaitingRoomCommand(
        String name,
        Integer maxPlayers,
        BigDecimal stakeAmount,
        GameType gameType,
        GameVariant gameVariant,
        Integer dealsPerMatch,
        RoomVisibility visibility,
        Long sourceGroupId
) {
    public CreateWaitingRoomCommand(
            String name,
            Integer maxPlayers,
            BigDecimal stakeAmount,
            GameType gameType,
            GameVariant gameVariant,
            Integer dealsPerMatch
    ) {
        this(name, maxPlayers, stakeAmount, gameType, gameVariant, dealsPerMatch, RoomVisibility.PUBLIC, null);
    }
}
