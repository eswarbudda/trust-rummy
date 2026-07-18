package com.trustrummy.backend.controller;

import com.trustrummy.backend.dto.AuthResponse;
import com.trustrummy.backend.dto.LoginRequest;
import com.trustrummy.backend.dto.LogoutRequest;
import com.trustrummy.backend.dto.RefreshTokenRequest;
import com.trustrummy.backend.dto.RegisterRequest;
import com.trustrummy.backend.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/** All routes here are {@code permitAll} (see SecurityConfig) — none require an existing Authorization header. */
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        return ResponseEntity.ok(authService.register(request));
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        return ResponseEntity.ok(authService.login(request));
    }

    @PostMapping("/refresh")
    public ResponseEntity<AuthResponse> refresh(@Valid @RequestBody RefreshTokenRequest request) {
        return ResponseEntity.ok(authService.refresh(request));
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(@RequestBody(required = false) LogoutRequest request) {
        authService.logout(request);
        return ResponseEntity.noContent().build();
    }
}
