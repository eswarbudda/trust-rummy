package com.trustrummy.backend.dto;

import com.trustrummy.backend.entity.WalletTransaction;
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
public class WalletTransactionResponse {
    private Long id;
    private String type;
    private BigDecimal amount;
    private BigDecimal balanceAfter;
    private String referenceRoomCode;
    private Instant createdAt;

    public static WalletTransactionResponse from(WalletTransaction tx) {
        return WalletTransactionResponse.builder()
                .id(tx.getId())
                .type(tx.getType().name())
                .amount(tx.getAmount())
                .balanceAfter(tx.getBalanceAfter())
                .referenceRoomCode(tx.getReferenceRoomCode())
                .createdAt(tx.getCreatedAt())
                .build();
    }
}
