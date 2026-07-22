package com.trustrummy.backend.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.function.Function;

/**
 * Production-grade JWT helper built exclusively on the modern
 * io.jsonwebtoken (jjwt) 0.12.x API surface.
 * <p>
 * IMPORTANT: this class intentionally avoids every deprecated jjwt 0.11.x
 * call ({@code Jwts.parser()}, {@code setSigningKey()}, etc.) in favor of
 * {@code Jwts.parser().verifyWith(key).build()} and
 * {@code Jwts.builder()...signWith(key)}.
 */
@Component
public class JwtTokenUtil {

    /**
     * Raw 256-bit (32+ character) secret, injected from application.properties
     * (jwt.secret). In production this MUST be supplied via an environment
     * variable / secrets manager, never committed to source control.
     */
    private final SecretKey signingKey;

    private final long expirationMs;

    public JwtTokenUtil(
            @Value("${jwt.secret}") String secret,
            @Value("${jwt.expiration-ms:900000}") long expirationMs
    ) {
        this.signingKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expirationMs = expirationMs;
    }

    /** Access-token lifetime in milliseconds (from {@code jwt.expiration-ms}). */
    public long getExpirationMs() {
        return expirationMs;
    }

    /** Generates a signed JWT for the given authenticated user. */
    public String generateToken(UserDetails userDetails) {
        return generateToken(new HashMap<>(), userDetails);
    }

    public String generateToken(Map<String, Object> extraClaims, UserDetails userDetails) {
        Date now = new Date();
        Date expiry = new Date(now.getTime() + expirationMs);

        return Jwts.builder()
                .claims(extraClaims)
                .subject(userDetails.getUsername())
                .issuedAt(now)
                .expiration(expiry)
                .signWith(signingKey)
                .compact();
    }

    /** Extracts the username (subject) embedded in the token. */
    public String extractUsername(String token) {
        return extractClaim(token, Claims::getSubject);
    }

    public Date extractExpiration(String token) {
        return extractClaim(token, Claims::getExpiration);
    }

    public <T> T extractClaim(String token, Function<Claims, T> claimsResolver) {
        Claims claims = extractAllClaims(token);
        return claimsResolver.apply(claims);
    }

    private Claims extractAllClaims(String token) {
        return Jwts.parser()
                .verifyWith(signingKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    /** Validates signature, expiry, and that the subject matches the given user. */
    public boolean validateToken(String token, UserDetails userDetails) {
        try {
            String username = extractUsername(token);
            // SAFE: If username is null, it gracefully returns false without crashing
            return (username != null && username.equals(userDetails.getUsername()) && !isTokenExpired(token));
        } catch (JwtException | IllegalArgumentException ex) {
            return false;
        }
    }

    /** Lightweight structural/signature validation without a UserDetails comparison. */
    public boolean isTokenValid(String token) {
        try {
            extractAllClaims(token);
            return true;
        } catch (JwtException | IllegalArgumentException ex) {
            return false;
        }
    }

    private boolean isTokenExpired(String token) {
        try {
            return extractExpiration(token).before(new Date());
        } catch (ExpiredJwtException ex) {
            return true;
        }
    }
}
