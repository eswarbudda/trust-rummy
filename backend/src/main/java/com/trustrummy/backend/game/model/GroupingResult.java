package com.trustrummy.backend.game.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * Best-effort (not necessarily full-coverage) grouping of a hand into
 * melds, used to score a losing hand: the melds are "matched" cards, the
 * leftover cards are deadwood whose point values count against the player.
 */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GroupingResult {
    private List<Meld> melds;
    private List<Card> leftoverCards;
    private int leftoverPoints;
}
