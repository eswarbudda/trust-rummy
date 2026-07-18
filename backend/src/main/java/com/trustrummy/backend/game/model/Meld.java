package com.trustrummy.backend.game.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

/** A validated, disjoint group of cards within a hand grouping. */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Meld {
    private MeldType type;
    private List<Card> cards;
}
