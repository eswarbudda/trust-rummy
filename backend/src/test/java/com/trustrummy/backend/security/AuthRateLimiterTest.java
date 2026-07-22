package com.trustrummy.backend.security;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AuthRateLimiterTest {

    @Test
    void blocksAfterMaxAttemptsInWindow() {
        AuthRateLimiter limiter = new AuthRateLimiter(3, 60_000);
        assertThatCode(() -> limiter.checkAndRecord("k")).doesNotThrowAnyException();
        assertThatCode(() -> limiter.checkAndRecord("k")).doesNotThrowAnyException();
        assertThatCode(() -> limiter.checkAndRecord("k")).doesNotThrowAnyException();
        assertThatThrownBy(() -> limiter.checkAndRecord("k"))
                .isInstanceOf(ResponseStatusException.class)
                .satisfies(ex -> assertThat(((ResponseStatusException) ex).getStatusCode())
                        .isEqualTo(HttpStatus.TOO_MANY_REQUESTS));
    }

    @Test
    void resetClearsBudget() {
        AuthRateLimiter limiter = new AuthRateLimiter(1, 60_000);
        limiter.checkAndRecord("k");
        assertThatThrownBy(() -> limiter.checkAndRecord("k"))
                .isInstanceOf(ResponseStatusException.class);
        limiter.reset("k");
        assertThatCode(() -> limiter.checkAndRecord("k")).doesNotThrowAnyException();
    }
}
