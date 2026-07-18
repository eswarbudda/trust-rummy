package com.trustrummy.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MatchPlayerResultResponse {
    private Long userId;
    private String username;
    private Integer seatNumber;
    private Integer finalScore;
    private String status;
}
