package com.trustrummy.backend.security;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class RefreshTokenHasherTest {

    @Test
    void sha256HexIsDeterministicAndNotPlaintext() {
        String raw = "opaque-refresh-secret";
        String hash = RefreshTokenHasher.sha256Hex(raw);
        assertThat(hash).hasSize(64);
        assertThat(hash).isEqualTo(RefreshTokenHasher.sha256Hex(raw));
        assertThat(hash).isNotEqualTo(raw);
        assertThat(hash).matches("[0-9a-f]{64}");
    }
}
