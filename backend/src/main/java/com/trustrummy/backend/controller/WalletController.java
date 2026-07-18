package com.trustrummy.backend.controller;

import com.trustrummy.backend.dto.WalletAmountRequest;
import com.trustrummy.backend.dto.WalletBalanceResponse;
import com.trustrummy.backend.dto.WalletTransactionResponse;
import com.trustrummy.backend.entity.User;
import com.trustrummy.backend.entity.WalletTransaction;
import com.trustrummy.backend.repository.UserRepository;
import com.trustrummy.backend.service.WalletService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/wallet")
@RequiredArgsConstructor
public class WalletController {

    private final UserRepository userRepository;
    private final WalletService walletService;

    @GetMapping("/balance")
    public ResponseEntity<WalletBalanceResponse> getBalance(@AuthenticationPrincipal UserDetails principal) {
        User user = userRepository.findByUsername(principal.getUsername())
                .orElseThrow(() -> new IllegalArgumentException("Unknown user"));

        return ResponseEntity.ok(WalletBalanceResponse.builder()
                .username(user.getUsername())
                .balance(user.getWalletBalance())
                .build());
    }

    @PostMapping("/deposit")
    public ResponseEntity<WalletBalanceResponse> deposit(
            @AuthenticationPrincipal UserDetails principal,
            @Valid @RequestBody WalletAmountRequest request
    ) {
        WalletTransaction tx = walletService.deposit(principal.getUsername(), request.getAmount());
        return ResponseEntity.ok(WalletBalanceResponse.builder()
                .username(principal.getUsername())
                .balance(tx.getBalanceAfter())
                .build());
    }

    @PostMapping("/withdraw")
    public ResponseEntity<WalletBalanceResponse> withdraw(
            @AuthenticationPrincipal UserDetails principal,
            @Valid @RequestBody WalletAmountRequest request
    ) {
        WalletTransaction tx = walletService.withdraw(principal.getUsername(), request.getAmount());
        return ResponseEntity.ok(WalletBalanceResponse.builder()
                .username(principal.getUsername())
                .balance(tx.getBalanceAfter())
                .build());
    }

    @GetMapping("/transactions")
    public ResponseEntity<Page<WalletTransactionResponse>> transactions(
            @AuthenticationPrincipal UserDetails principal,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        // Ordering already comes from the repository method name (OrderByCreatedAtDesc).
        Page<WalletTransaction> txPage = walletService.getTransactions(
                principal.getUsername(), PageRequest.of(page, size));
        return ResponseEntity.ok(txPage.map(WalletTransactionResponse::from));
    }
}
