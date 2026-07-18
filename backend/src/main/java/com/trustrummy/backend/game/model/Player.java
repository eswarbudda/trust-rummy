package com.trustrummy.backend.game.model;

import com.trustrummy.backend.entity.PlayerStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.ArrayList;
import java.util.List;

/**
 * In-memory representation of a player seated at a live {@link GameRoom}.
 * Plain, serializable data holder — draw/discard/turn logic arrives with
 * the game engine in a later phase.
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Player {

    private Long userId;

    private String username;

    private Integer seatNumber;

    @Builder.Default
    private List<Card> hand = new ArrayList<>();

    @Builder.Default
    private Integer score = 0;

    @Builder.Default
    private PlayerStatus status = PlayerStatus.JOINED;
}
