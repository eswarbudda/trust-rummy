package com.trustrummy.backend.game.engine;

import com.trustrummy.backend.game.model.Card;
import com.trustrummy.backend.game.model.DeclareResult;
import com.trustrummy.backend.game.model.MeldType;
import com.trustrummy.backend.game.model.Suit;
import com.trustrummy.backend.game.model.Value;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Ace may be low (A-2-3) or high (J-Q-K-A). Wrap K-A-2 stays illegal.
 */
class HandValidatorAceSequenceTest {

    private final HandValidator validator = new HandValidator();

    @Test
    void aceHighPureSequenceJackQueenKingAceIsValidDeclare() {
        // Pure J♥-Q♥-K♥-A♥ + impure seq + two sets covering 13.
        List<Card> hand = new ArrayList<>(List.of(
                card(Suit.HEARTS, Value.JACK),
                card(Suit.HEARTS, Value.QUEEN),
                card(Suit.HEARTS, Value.KING),
                card(Suit.HEARTS, Value.ACE),
                card(Suit.SPADES, Value.FOUR),
                card(Suit.SPADES, Value.FIVE),
                card(Suit.CLUBS, Value.SIX), // wild fills impure 4-5-6
                card(Suit.CLUBS, Value.SEVEN),
                card(Suit.DIAMONDS, Value.SEVEN),
                card(Suit.HEARTS, Value.SEVEN),
                card(Suit.CLUBS, Value.NINE),
                card(Suit.DIAMONDS, Value.NINE),
                card(Suit.SPADES, Value.NINE)
        ));

        DeclareResult result = validator.validateDeclare(hand, Value.SIX);

        assertThat(result.isValid()).isTrue();
        assertThat(result.getMelds())
                .anyMatch(m -> m.getType() == MeldType.PURE_SEQUENCE
                        && m.getCards().size() == 4
                        && m.getCards().stream().allMatch(c -> c.getSuit() == Suit.HEARTS));
    }

    @Test
    void aceLowPureSequenceStillValid() {
        List<Card> hand = List.of(
                card(Suit.HEARTS, Value.ACE),
                card(Suit.HEARTS, Value.TWO),
                card(Suit.HEARTS, Value.THREE),
                card(Suit.SPADES, Value.FOUR),
                card(Suit.SPADES, Value.FIVE),
                card(Suit.CLUBS, Value.SIX),
                card(Suit.CLUBS, Value.SEVEN),
                card(Suit.DIAMONDS, Value.SEVEN),
                card(Suit.HEARTS, Value.SEVEN),
                card(Suit.CLUBS, Value.NINE),
                card(Suit.DIAMONDS, Value.NINE),
                card(Suit.SPADES, Value.NINE),
                card(Suit.HEARTS, Value.NINE)
        );

        DeclareResult result = validator.validateDeclare(hand, Value.SIX);
        assertThat(result.isValid()).isTrue();
    }

    @Test
    void kingAceTwoDoesNotWrapAsSequence() {
        // Best-effort must not treat K-A-2 as a legal sequence candidate.
        List<Card> hand = List.of(
                card(Suit.HEARTS, Value.KING),
                card(Suit.HEARTS, Value.ACE),
                card(Suit.HEARTS, Value.TWO),
                card(Suit.SPADES, Value.FIVE),
                card(Suit.SPADES, Value.SIX),
                card(Suit.SPADES, Value.SEVEN),
                card(Suit.CLUBS, Value.NINE),
                card(Suit.DIAMONDS, Value.NINE),
                card(Suit.HEARTS, Value.NINE),
                card(Suit.CLUBS, Value.KING),
                card(Suit.DIAMONDS, Value.QUEEN),
                card(Suit.SPADES, Value.JACK),
                card(Suit.CLUBS, Value.TEN)
        );

        DeclareResult result = validator.validateDeclare(hand, Value.EIGHT);
        assertThat(result.isValid()).isFalse();
        assertThat(result.getMelds())
                .noneMatch(m -> m.getType() != null
                        && m.getType().isSequence()
                        && m.getCards().stream().anyMatch(c -> c.getValue() == Value.ACE)
                        && m.getCards().stream().anyMatch(c -> c.getValue() == Value.KING)
                        && m.getCards().stream().anyMatch(c -> c.getValue() == Value.TWO));
    }

    private static Card card(Suit suit, Value value) {
        return Card.builder().suit(suit).value(value).build();
    }
}
