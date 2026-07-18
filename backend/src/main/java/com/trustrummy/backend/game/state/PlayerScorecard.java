package com.trustrummy.backend.game.state;

import com.trustrummy.backend.game.model.MatchPlayerStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * A player's cumulative standing across the whole match (all deals so
 * far). Persists in {@code MatchState} for the lifetime of the match,
 * unlike per-deal hand/turn state which lives in {@code Deal}.
 */
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PlayerScorecard {

    private Long userId;

    private String username;

    private Integer seatNumber;

    @Builder.Default
    private int cumulativeScore = 0;

    @Builder.Default
    private MatchPlayerStatus matchStatus = MatchPlayerStatus.ACTIVE;

    public void addPoints(int points) {
        this.cumulativeScore += points;
    }
}
