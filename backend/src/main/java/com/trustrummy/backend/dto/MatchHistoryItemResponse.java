package com.trustrummy.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MatchHistoryItemResponse {
    private Long sessionId;
    private String roomCode;
    private String gameVariant;
    private BigDecimal stakeAmount;
    private String status;
    private String winnerUsername;
    private Integer myFinalScore;
    private Instant startedAt;
    private Instant endedAt;
}
