package com.trustrummy.backend.game.engine;

import com.trustrummy.backend.game.config.GameConfig;
import com.trustrummy.backend.game.model.Card;
import com.trustrummy.backend.game.model.GroupingResult;
import com.trustrummy.backend.game.model.Value;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Req. 7 scoring rules: converts a losing hand into points, and exposes
 * the flat drop/wrong-declare penalties. All results are capped at
 * {@code GameConfig#penaltyMaxCap}, per variant configuration.
 */
@Component
@RequiredArgsConstructor
public class ScoreCalculator {

    private final HandValidator handValidator;

    /**
     * Points a losing (non-declaring, non-dropped) player receives at
     * round end: full cap if they hold no pure sequence at all, otherwise
     * their best-effort deadwood total, capped.
     */
    public int computeLoserPoints(List<Card> hand, Value wildValue, GameConfig config) {
        if (!handValidator.hasPureSequence(hand, wildValue)) {
            return config.getPenaltyMaxCap();
        }
        GroupingResult grouping = handValidator.computeBestGrouping(hand, wildValue);
        return Math.min(grouping.getLeftoverPoints(), config.getPenaltyMaxCap());
    }

    public int wrongDeclarePoints(GameConfig config) {
        return config.getPenaltyWrongDeclare();
    }

    public int firstDropPoints(GameConfig config) {
        return config.getPenaltyFirstDrop();
    }

    public int middleDropPoints(GameConfig config) {
        return config.getPenaltyMiddleDrop();
    }
}
