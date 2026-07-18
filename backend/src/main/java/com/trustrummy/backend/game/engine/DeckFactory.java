package com.trustrummy.backend.game.engine;

import com.trustrummy.backend.game.model.Card;
import com.trustrummy.backend.game.model.Suit;
import com.trustrummy.backend.game.model.Value;

import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Builds the physical 106-card double deck (2 x 52 standard cards + 2
 * printed jokers) used for every 13-card Indian Rummy deal, regardless of
 * variant.
 */
public final class DeckFactory {

    public static final int DECKS = 2;
    public static final int PRINTED_JOKERS_PER_DECK = 1;
    public static final int TOTAL_CARDS = DECKS * (52 + PRINTED_JOKERS_PER_DECK); // 106

    private static final SecureRandom RANDOM = new SecureRandom();

    private DeckFactory() {
    }

    public static List<Card> buildShuffledDoubleDeck() {
        List<Card> cards = new ArrayList<>(TOTAL_CARDS);

        for (int deckNo = 0; deckNo < DECKS; deckNo++) {
            for (Suit suit : Suit.values()) {
                for (Value value : Value.values()) {
                    if (value == Value.JOKER) {
                        continue;
                    }
                    cards.add(Card.builder().suit(suit).value(value).build());
                }
            }
            for (int j = 0; j < PRINTED_JOKERS_PER_DECK; j++) {
                cards.add(Card.builder().value(Value.JOKER).build());
            }
        }

        Collections.shuffle(cards, RANDOM);
        return cards;
    }
}
