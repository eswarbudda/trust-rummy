package com.trustrummy.backend.exception;

/**
 * Thrown when a rotated (already-revoked) refresh token is presented again.
 * Mapped to HTTP 409. Must not roll back the revoke-all that accompanies it.
 */
public class RefreshTokenCompromisedException extends RuntimeException {

    public RefreshTokenCompromisedException(String message) {
        super(message);
    }
}
