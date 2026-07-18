package com.trustrummy.backend.game.ws;

import lombok.Getter;
import lombok.Setter;

/**
 * Inbound action envelope deserialized from raw WebSocket JSON. Only the
 * fields relevant to {@link #type} are populated by the client:
 * <ul>
 *   <li>{@code DRAW_CARD} -> {@link #source}</li>
 *   <li>{@code DISCARD_CARD} -> {@link #cardCode}</li>
 *   <li>{@code DECLARE}, {@code DROP}, {@code START_MATCH} -> no extra fields</li>
 * </ul>
 */
@Getter
@Setter
public class GameActionMessage {
    private ActionType type;
    private DrawSource source;
    private String cardCode;
}
