package com.trustrummy.backend.service;

import com.trustrummy.backend.dto.AuthResponse;
import com.trustrummy.backend.dto.LoginRequest;
import com.trustrummy.backend.dto.LogoutRequest;
import com.trustrummy.backend.dto.RefreshTokenRequest;
import com.trustrummy.backend.dto.RegisterRequest;
import com.trustrummy.backend.entity.RefreshToken;
import com.trustrummy.backend.entity.User;
import com.trustrummy.backend.exception.RefreshTokenCompromisedException;
import com.trustrummy.backend.repository.RefreshTokenRepository;
import com.trustrummy.backend.repository.UserRepository;
import com.trustrummy.backend.security.CustomUserDetailsService;
import com.trustrummy.backend.security.JwtTokenUtil;
import com.trustrummy.backend.security.RefreshTokenHasher;
import org.springframework.beans.factory.annotation.Value;
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
public class AuthService {

    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final CustomUserDetailsService userDetailsService;
    private final JwtTokenUtil jwtTokenUtil;
    private final RefreshTokenRepository refreshTokenRepository;
    private final long refreshExpirationMs;

    public AuthService(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            AuthenticationManager authenticationManager,
            CustomUserDetailsService userDetailsService,
            JwtTokenUtil jwtTokenUtil,
            RefreshTokenRepository refreshTokenRepository,
            @Value("${jwt.refresh-expiration-ms:2592000000}") long refreshExpirationMs
    ) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.authenticationManager = authenticationManager;
        this.userDetailsService = userDetailsService;
        this.jwtTokenUtil = jwtTokenUtil;
        this.refreshTokenRepository = refreshTokenRepository;
        this.refreshExpirationMs = refreshExpirationMs;
    }

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

    /**
     * Redeems a still-valid, unrevoked refresh token for a new access + refresh pair (rotation).
     * Reuse of an already-rotated (revoked) token revokes every active session for that user.
     * {@link RefreshTokenCompromisedException} must not roll back that revoke-all.
     */
    @Transactional(noRollbackFor = RefreshTokenCompromisedException.class)
    public AuthResponse refresh(RefreshTokenRequest request) {
        String presented = request.getRefreshToken();
        if (presented == null || presented.isBlank()) {
            throw new IllegalArgumentException("Invalid refresh token");
        }
        String tokenHash = RefreshTokenHasher.sha256Hex(presented);

        RefreshToken stored = refreshTokenRepository.findByToken(tokenHash)
                .orElseThrow(() -> new IllegalArgumentException("Invalid refresh token"));

        if (stored.isRevoked()) {
            // Suspected theft: someone replayed a rotated token.
            refreshTokenRepository.revokeAllActiveForUser(stored.getUser().getId());
            throw new RefreshTokenCompromisedException("Refresh token expired or revoked");
        }
        if (stored.getExpiresAt().isBefore(Instant.now())) {
            throw new IllegalStateException("Refresh token expired or revoked");
        }

        stored.setRevoked(true);
        refreshTokenRepository.save(stored);

        return issueAuthResponse(stored.getUser());
    }

    /** Access JWTs are short-lived and stateless; revoking the refresh token ends durable renewal. */
    @Transactional
    public void logout(LogoutRequest request) {
        if (request == null || request.getRefreshToken() == null || request.getRefreshToken().isBlank()) {
            return;
        }
        String tokenHash = RefreshTokenHasher.sha256Hex(request.getRefreshToken());
        refreshTokenRepository.findByToken(tokenHash)
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
                .expiresInMs(jwtTokenUtil.getExpirationMs())
                .refreshToken(refreshToken)
                .build();
    }

    /** Returns the opaque secret to the client; persists only its SHA-256 hash. */
    private String issueRefreshToken(User user) {
        byte[] randomBytes = new byte[48];
        SECURE_RANDOM.nextBytes(randomBytes);
        String rawToken = Base64.getUrlEncoder().withoutPadding().encodeToString(randomBytes);
        String tokenHash = RefreshTokenHasher.sha256Hex(rawToken);

        refreshTokenRepository.save(RefreshToken.builder()
                .token(tokenHash)
                .user(user)
                .expiresAt(Instant.now().plusMillis(refreshExpirationMs))
                .build());

        return rawToken;
    }
}
