package com.trustrummy.backend.game.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * Outcome of running {@code HandValidator} against a 13-card hand at
 * declare time. {@code valid == true} implies {@code melds} fully covers
 * the hand with >= 1 pure sequence and >= 2 sequences total.
 */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DeclareResult {
    private boolean valid;
    private List<Meld> melds;
    private String reason;
}
