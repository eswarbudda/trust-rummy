package com.trustrummy.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AuthResponse {
    private String token;
    private String tokenType;
    private String username;
    private Long expiresInMs;
    /** Opaque, long-lived token to redeem for a new access token via {@code POST /api/v1/auth/refresh}. */
    private String refreshToken;
}
