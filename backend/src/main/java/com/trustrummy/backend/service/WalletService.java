package com.trustrummy.backend.service;

import com.trustrummy.backend.entity.User;
import com.trustrummy.backend.entity.WalletTransaction;
import com.trustrummy.backend.entity.WalletTransactionType;
import com.trustrummy.backend.repository.UserRepository;
import com.trustrummy.backend.repository.WalletTransactionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

@Service
@RequiredArgsConstructor
public class WalletService {

    private final UserRepository userRepository;
    private final WalletTransactionRepository walletTransactionRepository;

    public User getUser(String username) {
        return userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalArgumentException("Unknown user: " + username));
    }

    @Transactional
    public WalletTransaction deposit(String username, BigDecimal amount) {
        validateAmount(amount);
        User user = getUser(username);
        user.setWalletBalance(user.getWalletBalance().add(amount));
        userRepository.save(user);
        return recordTransaction(user, WalletTransactionType.DEPOSIT, amount);
    }

    @Transactional
    public WalletTransaction withdraw(String username, BigDecimal amount) {
        validateAmount(amount);
        User user = getUser(username);
        if (user.getWalletBalance().compareTo(amount) < 0) {
            throw new IllegalStateException("Insufficient wallet balance");
        }
        user.setWalletBalance(user.getWalletBalance().subtract(amount));
        userRepository.save(user);
        return recordTransaction(user, WalletTransactionType.WITHDRAWAL, amount.negate());
    }

    public Page<WalletTransaction> getTransactions(String username, Pageable pageable) {
        User user = getUser(username);
        return walletTransactionRepository.findByUserIdOrderByCreatedAtDesc(user.getId(), pageable);
    }

    private WalletTransaction recordTransaction(User user, WalletTransactionType type, BigDecimal signedAmount) {
        WalletTransaction tx = WalletTransaction.builder()
                .user(user)
                .type(type)
                .amount(signedAmount)
                .balanceAfter(user.getWalletBalance())
                .build();
        return walletTransactionRepository.save(tx);
    }

    private void validateAmount(BigDecimal amount) {
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Amount must be positive");
        }
    }
}
