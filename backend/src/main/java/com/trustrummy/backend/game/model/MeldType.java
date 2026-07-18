package com.trustrummy.backend.game.model;

/** The three group shapes a valid Rummy hand can be decomposed into. */
public enum MeldType {
    /** 3+ consecutive same-suit cards, no jokers. */
    PURE_SEQUENCE,
    /** 3+ consecutive same-suit cards, using at least one joker as a filler. */
    IMPURE_SEQUENCE,
    /** 3-4 same-rank cards of distinct suits (optionally joker-filled). */
    SET;

    public boolean isSequence() {
        return this == PURE_SEQUENCE || this == IMPURE_SEQUENCE;
    }
}
