package com.trustrummy.backend.dto;

import com.trustrummy.backend.entity.GameMoveLog;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MoveLogResponse {
    private String username;
    private String moveType;
    private String moveData;
    private Long sequenceNo;
    private Instant createdAt;

    public static MoveLogResponse from(GameMoveLog log) {
        return MoveLogResponse.builder()
                .username(log.getUser().getUsername())
                .moveType(log.getMoveType().name())
                .moveData(log.getMoveData())
                .sequenceNo(log.getSequenceNo())
                .createdAt(log.getCreatedAt())
                .build();
    }
}
