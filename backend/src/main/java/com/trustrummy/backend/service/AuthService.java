package com.trustrummy.backend.service;

import com.trustrummy.backend.dto.AuthResponse;
import com.trustrummy.backend.dto.LoginRequest;
import com.trustrummy.backend.dto.LogoutRequest;
import com.trustrummy.backend.dto.RefreshTokenRequest;
import com.trustrummy.backend.dto.RegisterRequest;
import com.trustrummy.backend.entity.RefreshToken;
import com.trustrummy.backend.entity.User;
import com.trustrummy.backend.repository.RefreshTokenRepository;
import com.trustrummy.backend.repository.UserRepository;
import com.trustrummy.backend.security.CustomUserDetailsService;
import com.trustrummy.backend.security.JwtTokenUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;

@Service
@RequiredArgsConstructor
public class AuthService {

    private static final long DEFAULT_EXPIRATION_MS = 86_400_000L;
    private static final long REFRESH_TOKEN_EXPIRATION_MS = 30L * 24 * 60 * 60 * 1000; // 30 days
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final CustomUserDetailsService userDetailsService;
    private final JwtTokenUtil jwtTokenUtil;
    private final RefreshTokenRepository refreshTokenRepository;

    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByUsername(request.getUsername())) {
            throw new IllegalArgumentException("Username already taken");
        }
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new IllegalArgumentException("Email already registered");
        }

        User user = User.builder()
                .username(request.getUsername())
                .email(request.getEmail())
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .displayName(request.getDisplayName() != null ? request.getDisplayName() : request.getUsername())
                .build();

        userRepository.save(user);

        return issueAuthResponse(user);
    }

    public AuthResponse login(LoginRequest request) {
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getUsername(), request.getPassword())
        );

        User user = userRepository.findByUsername(request.getUsername())
                .orElseThrow(() -> new IllegalArgumentException("Unknown user: " + request.getUsername()));

        return issueAuthResponse(user);
    }

    /** Redeems a still-valid, unrevoked refresh token for a brand new access + refresh token pair (rotation). */
    @Transactional
    public AuthResponse refresh(RefreshTokenRequest request) {
        RefreshToken stored = refreshTokenRepository.findByToken(request.getRefreshToken())
                .orElseThrow(() -> new IllegalArgumentException("Invalid refresh token"));

        if (stored.isRevoked() || stored.getExpiresAt().isBefore(Instant.now())) {
            throw new IllegalStateException("Refresh token expired or revoked");
        }

        // Rotate: a used/replayed token is immediately worthless.
        stored.setRevoked(true);
        refreshTokenRepository.save(stored);

        return issueAuthResponse(stored.getUser());
    }

    /** Access JWTs are stateless (no blocklist yet); revoking the refresh token is the only durable server-side effect. */
    @Transactional
    public void logout(LogoutRequest request) {
        if (request == null || request.getRefreshToken() == null || request.getRefreshToken().isBlank()) {
            return;
        }
        refreshTokenRepository.findByToken(request.getRefreshToken())
                .ifPresent(rt -> {
                    rt.setRevoked(true);
                    refreshTokenRepository.save(rt);
                });
    }

    private AuthResponse issueAuthResponse(User user) {
        UserDetails userDetails = userDetailsService.loadUserByUsername(user.getUsername());
        String accessToken = jwtTokenUtil.generateToken(userDetails);
        String refreshToken = issueRefreshToken(user);

        return AuthResponse.builder()
                .token(accessToken)
                .tokenType("Bearer")
                .username(user.getUsername())
                .expiresInMs(DEFAULT_EXPIRATION_MS)
                .refreshToken(refreshToken)
                .build();
    }

    private String issueRefreshToken(User user) {
        byte[] randomBytes = new byte[48];
        SECURE_RANDOM.nextBytes(randomBytes);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(randomBytes);

        refreshTokenRepository.save(RefreshToken.builder()
                .token(token)
                .user(user)
                .expiresAt(Instant.now().plusMillis(REFRESH_TOKEN_EXPIRATION_MS))
                .build());

        return token;
    }
}
