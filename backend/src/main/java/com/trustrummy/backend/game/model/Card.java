package com.trustrummy.backend.game.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * A single playing card. Plain, serializable data holder — no shuffling,
 * dealing, or meld/validation logic lives here (that arrives with the game
 * engine in a later phase).
 * <p>
 * Printed jokers have {@code value == Value.JOKER} and {@code suit == null}.
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EqualsAndHashCode
public class Card {

    /** Null for printed jokers. */
    private Suit suit;

    private Value value;

    public boolean isPrintedJoker() {
        return value == Value.JOKER;
    }

    /** Compact wire code, e.g. "AS" (ace of spades), "10H", "JK" (printed joker). */
    public String getCode() {
        if (isPrintedJoker()) {
            return value.getShortCode();
        }
        return value.getShortCode() + suit.getShortCode();
    }

    @Override
    public String toString() {
        return getCode();
    }
}
