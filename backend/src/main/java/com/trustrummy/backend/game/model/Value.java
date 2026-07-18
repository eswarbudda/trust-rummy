package com.trustrummy.backend.game.model;

/**
 * The face value of a card, plus the printed {@code JOKER}. This only
 * carries intrinsic card data (short code, face point value); it does not
 * encode any rummy-specific scoring or meld rules.
 */
public enum Value {
    ACE(1, "A"),
    TWO(2, "2"),
    THREE(3, "3"),
    FOUR(4, "4"),
    FIVE(5, "5"),
    SIX(6, "6"),
    SEVEN(7, "7"),
    EIGHT(8, "8"),
    NINE(9, "9"),
    TEN(10, "10"),
    JACK(10, "J"),
    QUEEN(10, "Q"),
    KING(10, "K"),
    JOKER(0, "JK");

    private final int points;
    private final String shortCode;

    Value(int points, String shortCode) {
        this.points = points;
        this.shortCode = shortCode;
    }

    public int getPoints() {
        return points;
    }

    public String getShortCode() {
        return shortCode;
    }
}
