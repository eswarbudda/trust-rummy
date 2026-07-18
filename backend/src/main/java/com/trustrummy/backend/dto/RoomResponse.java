package com.trustrummy.backend.dto;

import com.trustrummy.backend.entity.GameRoom;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RoomResponse {
    private Long id;
    private String roomCode;
    private String name;
    private Integer maxPlayers;
    private BigDecimal stakeAmount;
    private String status;
    private String gameVariant;

    public static RoomResponse from(GameRoom room) {
        return RoomResponse.builder()
                .id(room.getId())
                .roomCode(room.getRoomCode())
                .name(room.getName())
                .maxPlayers(room.getMaxPlayers())
                .stakeAmount(room.getStakeAmount())
                .status(room.getStatus().name())
                .gameVariant(room.getGameVariant() != null ? room.getGameVariant().name() : null)
                .build();
    }
}
