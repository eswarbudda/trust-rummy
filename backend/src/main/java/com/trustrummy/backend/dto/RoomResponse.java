package com.trustrummy.backend.dto;

import com.trustrummy.backend.entity.GameRoom;
import com.trustrummy.backend.entity.RoomPlayer;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

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
    private String gameType;
    private String gameVariant;
    /** Only populated by endpoints that already have the seated players loaded (create/join). */
    private List<RoomPlayerSummary> players;

    public static RoomResponse from(GameRoom room) {
        return from(room, null);
    }

    public static RoomResponse from(GameRoom room, List<RoomPlayer> seatedPlayers) {
        return RoomResponse.builder()
                .id(room.getId())
                .roomCode(room.getRoomCode())
                .name(room.getName())
                .maxPlayers(room.getMaxPlayers())
                .stakeAmount(room.getStakeAmount())
                .status(room.getStatus().name())
                .gameType(room.getGameType() != null ? room.getGameType().name() : null)
                .gameVariant(room.getGameVariant() != null ? room.getGameVariant().name() : null)
                .players(seatedPlayers == null ? null : seatedPlayers.stream()
                        .map(rp -> RoomPlayerSummary.builder()
                                .userId(rp.getUser().getId())
                                .username(rp.getUser().getUsername())
                                .seatNumber(rp.getSeatNumber())
                                .status(rp.getStatus().name())
                                .build())
                        .toList())
                .build();
    }
}
