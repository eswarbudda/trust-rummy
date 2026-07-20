package com.trustrummy.backend.service.settlement;

/**
 * Minimal seat identity for stake collection (avoids coupling settlement to JPA entities).
 */
public record SeatedPlayer(Long userId, String username) {
}
