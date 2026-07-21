package com.trustrummy.backend.game.ws;

/** Inbound WebSocket action types accepted on {@code /ws/game/{roomCode}}. */
public enum ActionType {
    START_MATCH,
    START_NEXT_DEAL,
    LEAVE_TABLE,
    DRAW_CARD,
    DISCARD_CARD,
    DECLARE,
    DROP
}
