package com.trustrummy.backend.game.model;

/**
 * The four standard card suits. Printed jokers have no suit
 * (see {@link Card#isPrintedJoker()}).
 */
public enum Suit {
    SPADES("S"),
    HEARTS("H"),
    DIAMONDS("D"),
    CLUBS("C");

    private final String shortCode;

    Suit(String shortCode) {
        this.shortCode = shortCode;
    }

    public String getShortCode() {
        return shortCode;
    }
}
