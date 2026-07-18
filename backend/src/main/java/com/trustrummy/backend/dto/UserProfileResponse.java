package com.trustrummy.backend.dto;

import com.trustrummy.backend.entity.User;
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
public class UserProfileResponse {
    private Long id;
    private String username;
    private String email;
    private String displayName;
    private BigDecimal walletBalance;
    private String role;
    private Instant createdAt;

    public static UserProfileResponse from(User user) {
        return UserProfileResponse.builder()
                .id(user.getId())
                .username(user.getUsername())
                .email(user.getEmail())
                .displayName(user.getDisplayName())
                .walletBalance(user.getWalletBalance())
                .role(user.getRole())
                .createdAt(user.getCreatedAt())
                .build();
    }
}
