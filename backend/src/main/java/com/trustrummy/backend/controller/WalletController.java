package com.trustrummy.backend.controller;

import com.trustrummy.backend.dto.WalletBalanceResponse;
import com.trustrummy.backend.entity.User;
import com.trustrummy.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Wallet endpoints are intentionally minimal stubs in Phase 1 - just enough
 * to expose the balance stored on the User entity. Deposits/withdrawals and
 * ledger tracking arrive in a later phase.
 */
@RestController
@RequestMapping("/api/v1/wallet")
@RequiredArgsConstructor
public class WalletController {

    private final UserRepository userRepository;

    @GetMapping("/balance")
    public ResponseEntity<WalletBalanceResponse> getBalance(@AuthenticationPrincipal UserDetails principal) {
        User user = userRepository.findByUsername(principal.getUsername())
                .orElseThrow(() -> new IllegalArgumentException("Unknown user"));

        return ResponseEntity.ok(WalletBalanceResponse.builder()
                .username(user.getUsername())
                .balance(user.getWalletBalance())
                .build());
    }
}
