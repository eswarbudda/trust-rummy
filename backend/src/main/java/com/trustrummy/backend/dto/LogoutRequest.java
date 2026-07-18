package com.trustrummy.backend.dto;

import lombok.Getter;
import lombok.Setter;

/**
 * The access JWT is stateless and cannot be server-side invalidated without a
 * blocklist (not implemented yet), so logout's only real effect today is
 * revoking the refresh token, if one is supplied.
 */
@Getter
@Setter
public class LogoutRequest {
    private String refreshToken;
}
