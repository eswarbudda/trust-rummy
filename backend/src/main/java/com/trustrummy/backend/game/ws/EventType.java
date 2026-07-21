package com.trustrummy.backend.game.ws;

/** Outbound WebSocket event types broadcast on {@code /ws/game/{roomCode}}. */
public enum EventType {
    ROOM_STATE,
    DEAL_STARTED,
    TURN_STATE,
    CARD_DRAWN,
    CARD_DISCARDED,
    PLAYER_DROPPED,
    DECLARE_RESULT,
    SCORE_UPDATE,
    DEAL_RESULT,
    PLAYER_ELIMINATED,
    MATCH_ENDED,
    ERROR
}
