package com.trustrummy.backend.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
public class RoomCreateRequest {

    private String name;

    @NotNull
    @Min(2)
    @Max(6)
    private Integer maxPlayers;

    @NotNull
    private BigDecimal stakeAmount;
}
