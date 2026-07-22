package com.trustrummy.backend.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Iterator;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Lightweight in-memory sliding-window limiter for auth endpoints (MVP).
 * Not a substitute for edge WAF / Redis in large deployments.
 */
@Component
public class AuthRateLimiter {

    private final int maxAttempts;
    private final long windowMs;
    private final Map<String, Deque<Long>> attemptsByKey = new ConcurrentHashMap<>();

    public AuthRateLimiter(
            @Value("${auth.rate-limit.max-attempts:20}") int maxAttempts,
            @Value("${auth.rate-limit.window-ms:300000}") long windowMs
    ) {
        this.maxAttempts = maxAttempts;
        this.windowMs = windowMs;
    }

    /**
     * Records an attempt and throws 429 when the key exceeds the window budget.
     *
     * @param key typically {@code "login:ip:username"} or {@code "register:ip"}
     */
    public void checkAndRecord(String key) {
        long now = Instant.now().toEpochMilli();
        Deque<Long> times = attemptsByKey.computeIfAbsent(key, k -> new ArrayDeque<>());
        synchronized (times) {
            prune(times, now);
            if (times.size() >= maxAttempts) {
                throw new ResponseStatusException(
                        HttpStatus.TOO_MANY_REQUESTS,
                        "Too many authentication attempts. Try again later.");
            }
            times.addLast(now);
        }
    }

    /** Clears the window for a key after a successful login (reduces lockout for legitimate users). */
    public void reset(String key) {
        attemptsByKey.remove(key);
    }

    private void prune(Deque<Long> times, long now) {
        long cutoff = now - windowMs;
        Iterator<Long> it = times.iterator();
        while (it.hasNext()) {
            if (it.next() < cutoff) {
                it.remove();
            } else {
                break;
            }
        }
    }
}
