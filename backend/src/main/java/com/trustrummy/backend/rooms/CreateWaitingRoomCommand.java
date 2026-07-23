package com.trustrummy.backend.rooms;

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
        Integer dealsPerMatch
) {
}
