package com.trustrummy.backend.game.model;

/** Group shapes used in declare validation and wrong-show reveal. */
public enum MeldType {
    /** 3+ consecutive same-suit cards, no jokers. */
    PURE_SEQUENCE,
    /** 3+ consecutive same-suit cards, using at least one joker as a filler. */
    IMPURE_SEQUENCE,
    /** 3-4 same-rank cards of distinct suits (optionally joker-filled). */
    SET,
    /**
     * Cards that could not be placed in any legal meld on a wrong show —
     * shown to the whole room so everyone can see what failed.
     */
    UNMATCHED,
    /** The 14th card set aside when finishing a declare (not part of the 13). */
    SET_ASIDE;

    public boolean isSequence() {
        return this == PURE_SEQUENCE || this == IMPURE_SEQUENCE;
    }

    /** Legal in-hand group (not leftover / not the finish card). */
    public boolean isLegalGroup() {
        return this == PURE_SEQUENCE || this == IMPURE_SEQUENCE || this == SET;
    }
}
