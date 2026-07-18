package com.trustrummy.backend.game.model;

/** A player's status within the *current* deal only (reset every deal). */
public enum RoundStatus {
    PLAYING,
    DROPPED,
    DECLARED_VALID,
    DECLARED_WRONG
}
