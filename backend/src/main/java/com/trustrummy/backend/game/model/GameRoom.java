package com.trustrummy.backend.game.model;

import com.trustrummy.backend.entity.RoomStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

/**
 * In-memory, serializable structure describing a live game room's players
 * and card piles. This is distinct from the persisted
 * {@code com.trustrummy.backend.entity.GameRoom} JPA entity — that entity
 * is the durable record; this class is the runtime shape used on the
 * gameplay hot path. Plain data holder — no shuffling, dealing, or turn
 * logic lives here (that arrives with the game engine in a later phase).
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GameRoom {

    private String roomCode;

    private String name;

    private Integer maxPlayers;

    private BigDecimal stakeAmount;

    @Builder.Default
    private RoomStatus status = RoomStatus.WAITING;

    @Builder.Default
    private List<Player> players = new ArrayList<>();

    @Builder.Default
    private List<Card> drawPile = new ArrayList<>();

    @Builder.Default
    private List<Card> discardPile = new ArrayList<>();
}
