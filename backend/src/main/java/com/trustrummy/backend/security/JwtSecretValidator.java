package com.trustrummy.backend.security;

import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Refuses to start with the committed development JWT secret unless
 * {@code jwt.allow-insecure-default=true} (local/dev only).
 */
@Component
public class JwtSecretValidator {

    static final String INSECURE_DEFAULT_SECRET = "change-this-dev-only-secret-key-min-32-chars!!";

    private final String secret;
    private final boolean allowInsecureDefault;

    public JwtSecretValidator(
            @Value("${jwt.secret}") String secret,
            @Value("${jwt.allow-insecure-default:false}") boolean allowInsecureDefault
    ) {
        this.secret = secret;
        this.allowInsecureDefault = allowInsecureDefault;
    }

    @PostConstruct
    void validate() {
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException("jwt.secret must be set (env JWT_SECRET)");
        }
        if (secret.getBytes(java.nio.charset.StandardCharsets.UTF_8).length < 32) {
            throw new IllegalStateException("jwt.secret must be at least 32 bytes for HMAC-SHA256");
        }
        if (INSECURE_DEFAULT_SECRET.equals(secret) && !allowInsecureDefault) {
            throw new IllegalStateException(
                    "Refusing to start with the default jwt.secret. "
                            + "Set env JWT_SECRET to a strong value, or set "
                            + "jwt.allow-insecure-default=true for local development only.");
        }
    }
}
