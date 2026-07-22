package com.trustrummy.backend.game.engine;

import com.trustrummy.backend.game.model.Card;
import com.trustrummy.backend.game.model.DeclareResult;
import com.trustrummy.backend.game.model.Meld;
import com.trustrummy.backend.game.model.MeldType;
import com.trustrummy.backend.game.model.Suit;
import com.trustrummy.backend.game.model.Value;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class HandValidatorWrongShowTest {

    private final HandValidator validator = new HandValidator();

    @Test
    void invalidDeclareReturnsGroupedMeldsAndUnmatchedLeftovers() {
        // Two natural sequences + a set leave three high cards unmatched —
        // not a valid declare (needs a second sequence covering more / full 13).
        List<Card> hand = List.of(
                card(Suit.HEARTS, Value.ACE),
                card(Suit.HEARTS, Value.TWO),
                card(Suit.HEARTS, Value.THREE),
                card(Suit.SPADES, Value.FIVE),
                card(Suit.SPADES, Value.SIX),
                card(Suit.SPADES, Value.SEVEN),
                card(Suit.CLUBS, Value.NINE),
                card(Suit.DIAMONDS, Value.NINE),
                card(Suit.HEARTS, Value.NINE),
                card(Suit.CLUBS, Value.KING),
                card(Suit.DIAMONDS, Value.QUEEN),
                card(Suit.SPADES, Value.JACK),
                card(Suit.HEARTS, Value.TEN)
        );

        DeclareResult result = validator.validateDeclare(hand, Value.TWO);

        assertThat(result.isValid()).isFalse();
        assertThat(result.getReason()).isNotBlank();
        assertThat(result.getReason()).containsIgnoringCase("wrong show");
        assertThat(result.getMelds()).isNotEmpty();

        boolean hasUnmatched = result.getMelds().stream()
                .anyMatch(m -> m.getType() == MeldType.UNMATCHED);
        assertThat(hasUnmatched)
                .as("wrong show should expose leftover cards as UNMATCHED")
                .isTrue();

        int covered = result.getMelds().stream()
                .mapToInt(m -> m.getCards().size())
                .sum();
        assertThat(covered).isEqualTo(13);
    }

    @Test
    void validDeclareReturnsOnlyLegalMelds() {
        // Pure sequence + impure sequence + two sets covering all 13.
        List<Card> hand = List.of(
                card(Suit.HEARTS, Value.ACE),
                card(Suit.HEARTS, Value.TWO),
                card(Suit.HEARTS, Value.THREE),
                card(Suit.SPADES, Value.FOUR),
                card(Suit.SPADES, Value.FIVE),
                card(Suit.CLUBS, Value.SIX), // wild joker fills impure sequence 4-5-JK
                card(Suit.CLUBS, Value.SEVEN),
                card(Suit.DIAMONDS, Value.SEVEN),
                card(Suit.HEARTS, Value.SEVEN),
                card(Suit.CLUBS, Value.NINE),
                card(Suit.DIAMONDS, Value.NINE),
                card(Suit.SPADES, Value.NINE),
                card(Suit.HEARTS, Value.NINE)
        );

        // Wild = SIX so clubs-6 acts as joker for the impure sequence.
        DeclareResult result = validator.validateDeclare(hand, Value.SIX);

        assertThat(result.isValid()).isTrue();
        assertThat(result.getMelds()).isNotEmpty();
        assertThat(result.getMelds())
                .extracting(Meld::getType)
                .doesNotContain(MeldType.UNMATCHED, MeldType.SET_ASIDE);
        assertThat(result.getMelds())
                .allMatch(m -> m.getType() != null && m.getType().isLegalGroup());
    }

    private static Card card(Suit suit, Value value) {
        return Card.builder().suit(suit).value(value).build();
    }
}
