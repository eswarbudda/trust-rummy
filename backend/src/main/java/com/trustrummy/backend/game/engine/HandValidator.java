package com.trustrummy.backend.game.engine;

import com.trustrummy.backend.game.model.Card;
import com.trustrummy.backend.game.model.DeclareResult;
import com.trustrummy.backend.game.model.GroupingResult;
import com.trustrummy.backend.game.model.Meld;
import com.trustrummy.backend.game.model.MeldType;
import com.trustrummy.backend.game.model.Suit;
import com.trustrummy.backend.game.model.Value;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;

/**
 * Rummy hand-grouping engine. Given a hand and the deal's wild value, it
 * can:
 * <ul>
 *   <li>{@link #validateDeclare} — strict, all-13-cards-covered check used
 *       when a player clicks Declare/Show (Req. 6).</li>
 *   <li>{@link #hasPureSequence} / {@link #computeBestGrouping} — best-effort
 *       (partial-coverage) grouping used to score a losing hand, minimizing
 *       leftover deadwood (Req. 7).</li>
 * </ul>
 * <p>
 * A card counts as a joker (wild) if it is a printed joker OR its value
 * matches the deal's wild value — but the same physical card may still be
 * used in its own natural rank/suit within a specific candidate group
 * (e.g. three wild-value cards of different suits are a perfectly legal
 * natural SET). Candidate generation below tries every 3- and 4-card
 * combination independently, so both interpretations are explored.
 * <p>
 * Assumption: Ace may rank low (A-2-3) or high (Q-K-A / J-Q-K-A). Sequences
 * never wrap around (K-A-2 is illegal).
 */
@Component
public class HandValidator {

    private static final int MIN_GROUP_SIZE = 3;
    private static final int MAX_GROUP_SIZE = 4;
    /** Ace-low ladder: ACE=0 … KING=12. */
    private static final int RANK_CEILING_LOW = 12;
    /** Ace-high ladder: TWO=1 … KING=12, ACE=13. */
    private static final int RANK_FLOOR_HIGH = 1;
    private static final int RANK_CEILING_HIGH = 13;

    // ------------------------------------------------------------------
    // Strict declare validation
    // ------------------------------------------------------------------

    public DeclareResult validateDeclare(List<Card> hand, Value wildValue) {
        if (hand.size() != 13) {
            return DeclareResult.builder()
                    .valid(false)
                    .melds(List.of())
                    .reason("Hand must contain exactly 13 cards to declare")
                    .build();
        }

        List<CandidateMeld> candidates = generateCandidates(hand, wildValue);
        int fullMask = (1 << hand.size()) - 1;

        List<Meld> result = backtrackDeclare(candidates, 0, fullMask, new ArrayList<>(), 0, 0);
        if (result != null) {
            return DeclareResult.builder().valid(true).melds(result).reason("Valid declaration").build();
        }

        // Wrong show: still reveal best-effort groups + unmatched cards so the
        // whole room can see which cards / pairs failed the declare rules.
        GroupingResult grouping = computeBestGrouping(hand, wildValue);
        List<Meld> reveal = new ArrayList<>(grouping.getMelds());
        if (!grouping.getLeftoverCards().isEmpty()) {
            reveal.add(new Meld(MeldType.UNMATCHED, grouping.getLeftoverCards()));
        }
        return DeclareResult.builder()
                .valid(false)
                .melds(reveal)
                .reason(diagnoseInvalidDeclare(grouping))
                .build();
    }

    /**
     * Explains why a best-effort grouping is still an invalid declare
     * (missing pure sequence, second sequence, or leftover cards).
     */
    private static String diagnoseInvalidDeclare(GroupingResult grouping) {
        boolean hasPure = false;
        int sequenceCount = 0;
        for (Meld meld : grouping.getMelds()) {
            if (meld.getType() == MeldType.PURE_SEQUENCE) {
                hasPure = true;
            }
            if (meld.getType() != null && meld.getType().isSequence()) {
                sequenceCount++;
            }
        }
        if (!grouping.getLeftoverCards().isEmpty()) {
            return "Wrong show — highlighted cards are not in a valid set or sequence";
        }
        if (!hasPure) {
            return "Wrong show — need at least one pure sequence (no jokers)";
        }
        if (sequenceCount < 2) {
            return "Wrong show — need at least two sequences (including one pure)";
        }
        return "Wrong show — hand does not satisfy declare grouping rules";
    }

    private List<Meld> backtrackDeclare(
            List<CandidateMeld> candidates,
            int usedMask,
            int fullMask,
            List<Meld> chosen,
            int pureCount,
            int sequenceCount
    ) {
        if (usedMask == fullMask) {
            if (pureCount >= 1 && sequenceCount >= 2) {
                return new ArrayList<>(chosen);
            }
            return null;
        }

        int lowestUncovered = Integer.numberOfTrailingZeros(~usedMask & fullMask);

        for (CandidateMeld candidate : candidates) {
            if ((candidate.mask & (1 << lowestUncovered)) == 0) {
                continue; // canonical ordering: must cover the lowest uncovered card
            }
            if ((candidate.mask & usedMask) != 0) {
                continue; // overlaps an already-used card
            }

            chosen.add(new Meld(candidate.type, candidate.cards));
            int nextPure = pureCount + (candidate.type == MeldType.PURE_SEQUENCE ? 1 : 0);
            int nextSeq = sequenceCount + (candidate.type.isSequence() ? 1 : 0);

            List<Meld> found = backtrackDeclare(candidates, usedMask | candidate.mask, fullMask, chosen, nextPure, nextSeq);
            if (found != null) {
                return found;
            }
            chosen.remove(chosen.size() - 1);
        }
        return null;
    }

    // ------------------------------------------------------------------
    // Loser scoring support
    // ------------------------------------------------------------------

    public boolean hasPureSequence(List<Card> hand, Value wildValue) {
        for (CandidateMeld candidate : generateCandidates(hand, wildValue)) {
            if (candidate.type == MeldType.PURE_SEQUENCE) {
                return true;
            }
        }
        return false;
    }

    /** Best-effort grouping that minimizes leftover deadwood (partial coverage allowed). */
    public GroupingResult computeBestGrouping(List<Card> hand, Value wildValue) {
        List<CandidateMeld> candidates = generateCandidates(hand, wildValue);
        int n = hand.size();
        int fullMask = (1 << n) - 1;

        Map<Integer, BestState> memo = new HashMap<>();
        BestState best = solve(0, fullMask, candidates, memo);

        // Coverage is tracked purely via bitmask (hand index), never via Card#equals —
        // the 2-deck shoe contains duplicate suit/rank cards that would otherwise be
        // conflated by value-based equality.
        List<Card> leftover = new ArrayList<>();
        int leftoverPoints = 0;
        for (int i = 0; i < n; i++) {
            if ((best.matchedMask & (1 << i)) == 0) {
                Card c = hand.get(i);
                leftover.add(c);
                leftoverPoints += deadwoodValue(c, wildValue);
            }
        }

        return GroupingResult.builder()
                .melds(best.melds)
                .leftoverCards(leftover)
                .leftoverPoints(leftoverPoints)
                .build();
    }

    public static int deadwoodValue(Card card, Value wildValue) {
        if (card.isPrintedJoker() || card.getValue() == wildValue) {
            return 0;
        }
        return card.getValue().getPoints();
    }

    /**
     * {@code usedMask} is search progress (which hand indices have been *decided* —
     * either matched into a meld or explicitly left as deadwood); it always reaches
     * {@code fullMask} at the recursion's base case. {@code BestState#matchedMask} is
     * the (much smaller) subset of those decided cards that actually ended up inside a
     * chosen meld — that's what leftover/deadwood reconstruction needs.
     */
    private BestState solve(int usedMask, int fullMask, List<CandidateMeld> candidates, Map<Integer, BestState> memo) {
        if (usedMask == fullMask) {
            return new BestState(0, 0, List.of());
        }
        BestState cached = memo.get(usedMask);
        if (cached != null) {
            return cached;
        }

        int lowestUncovered = Integer.numberOfTrailingZeros(~usedMask & fullMask);

        // Option 1: leave the lowest uncovered card as deadwood.
        BestState best = solve(usedMask | (1 << lowestUncovered), fullMask, candidates, memo);

        // Option 2: cover it with any disjoint candidate meld (removes its natural point value from deadwood).
        for (CandidateMeld candidate : candidates) {
            if ((candidate.mask & (1 << lowestUncovered)) == 0) {
                continue;
            }
            if ((candidate.mask & usedMask) != 0) {
                continue;
            }
            BestState rest = solve(usedMask | candidate.mask, fullMask, candidates, memo);
            int totalValue = candidate.naturalPointValue + rest.value;
            if (totalValue > best.value) {
                List<Meld> melds = new ArrayList<>();
                melds.add(new Meld(candidate.type, candidate.cards));
                melds.addAll(rest.melds);
                best = new BestState(rest.matchedMask | candidate.mask, totalValue, melds);
            }
        }

        memo.put(usedMask, best);
        return best;
    }

    private static final class BestState {
        final int matchedMask;
        final int value;
        final List<Meld> melds;

        BestState(int matchedMask, int value, List<Meld> melds) {
            this.matchedMask = matchedMask;
            this.value = value;
            this.melds = melds;
        }
    }

    // ------------------------------------------------------------------
    // Candidate generation & classification
    // ------------------------------------------------------------------

    private List<CandidateMeld> generateCandidates(List<Card> hand, Value wildValue) {
        List<CandidateMeld> candidates = new ArrayList<>();
        int n = hand.size();
        for (int size = MIN_GROUP_SIZE; size <= MAX_GROUP_SIZE; size++) {
            if (size > n) {
                continue;
            }
            for (int[] combo : combinationsOfSize(n, size)) {
                int mask = 0;
                List<Card> subset = new ArrayList<>(size);
                for (int idx : combo) {
                    mask |= (1 << idx);
                    subset.add(hand.get(idx));
                }
                MeldType type = classify(subset, wildValue);
                if (type != null) {
                    int naturalPointValue = 0;
                    for (Card c : subset) {
                        naturalPointValue += deadwoodValue(c, wildValue);
                    }
                    candidates.add(new CandidateMeld(mask, type, subset, naturalPointValue));
                }
            }
        }
        return candidates;
    }

    private MeldType classify(List<Card> subset, Value wildValue) {
        int size = subset.size();
        if (size < MIN_GROUP_SIZE || size > MAX_GROUP_SIZE) {
            return null;
        }

        List<Card> wilds = new ArrayList<>();
        List<Card> naturals = new ArrayList<>();
        for (Card c : subset) {
            if (c.isPrintedJoker() || c.getValue() == wildValue) {
                wilds.add(c);
            } else {
                naturals.add(c);
            }
        }
        if (naturals.isEmpty()) {
            return null; // no natural anchor card; ambiguous meld, disallow
        }

        if (isSetShape(naturals)) {
            return MeldType.SET;
        }

        return classifySequence(naturals, wilds.size());
    }

    private boolean isSetShape(List<Card> naturals) {
        Value rank = naturals.get(0).getValue();
        Set<Suit> suits = new HashSet<>();
        for (Card c : naturals) {
            if (c.getValue() != rank) {
                return false;
            }
            if (!suits.add(c.getSuit())) {
                return false; // duplicate suit -> invalid set
            }
        }
        return true;
    }

    /**
     * Same-suit run. Ace may be low (A-2-3…) or high (…Q-K-A); K-A-2 wrap is
     * never allowed. Tries ace-low first, then ace-high when an Ace is present.
     */
    private MeldType classifySequence(List<Card> naturals, int jokerCount) {
        MeldType low = classifySequenceRanks(naturals, jokerCount, false);
        if (low != null) {
            return low;
        }
        boolean hasAce = false;
        for (Card c : naturals) {
            if (c.getValue() == Value.ACE) {
                hasAce = true;
                break;
            }
        }
        return hasAce ? classifySequenceRanks(naturals, jokerCount, true) : null;
    }

    private MeldType classifySequenceRanks(List<Card> naturals, int jokerCount, boolean aceHigh) {
        Suit suit = naturals.get(0).getSuit();
        Set<Integer> ranks = new TreeSet<>();
        for (Card c : naturals) {
            if (c.getSuit() != suit) {
                return null; // sequences must be single-suit
            }
            int rank = sequenceRank(c.getValue(), aceHigh);
            if (!ranks.add(rank)) {
                return null; // duplicate rank within a sequence
            }
        }

        int min = Collections.min(ranks);
        int max = Collections.max(ranks);
        int span = max - min + 1;
        int internalGaps = span - naturals.size();
        if (internalGaps < 0 || internalGaps > jokerCount) {
            return null;
        }
        int extension = jokerCount - internalGaps;
        int floor = aceHigh ? RANK_FLOOR_HIGH : 0;
        int ceiling = aceHigh ? RANK_CEILING_HIGH : RANK_CEILING_LOW;
        int roomBelow = min - floor;
        int roomAbove = ceiling - max;
        if (roomBelow + roomAbove < extension) {
            return null; // not enough room to place remaining jokers
        }
        return jokerCount == 0 ? MeldType.PURE_SEQUENCE : MeldType.IMPURE_SEQUENCE;
    }

    /** Rank used inside a sequence attempt (ace-low: 0…12, ace-high: 1…13). */
    private static int sequenceRank(Value value, boolean aceHigh) {
        if (value == Value.ACE) {
            return aceHigh ? RANK_CEILING_HIGH : 0;
        }
        return value.ordinal(); // TWO=1 … KING=12
    }

    private List<int[]> combinationsOfSize(int n, int k) {
        List<int[]> result = new ArrayList<>();
        combineHelper(result, new int[k], 0, 0, n, k);
        return result;
    }

    private void combineHelper(List<int[]> result, int[] combo, int start, int depth, int n, int k) {
        if (depth == k) {
            result.add(combo.clone());
            return;
        }
        for (int i = start; i < n; i++) {
            combo[depth] = i;
            combineHelper(result, combo, i + 1, depth + 1, n, k);
        }
    }

    private static final class CandidateMeld {
        final int mask;
        final MeldType type;
        final List<Card> cards;
        /** Sum of {@link #deadwoodValue} over this meld's cards — the deadwood removed by matching it. */
        final int naturalPointValue;

        CandidateMeld(int mask, MeldType type, List<Card> cards, int naturalPointValue) {
            this.mask = mask;
            this.type = type;
            this.cards = cards;
            this.naturalPointValue = naturalPointValue;
        }
    }
}
