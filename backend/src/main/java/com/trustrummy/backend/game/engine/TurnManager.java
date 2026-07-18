package com.trustrummy.backend.game.engine;

import jakarta.annotation.PreDestroy;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Req. 4 turn-timeout hook. Schedules a single cancellable countdown per
 * room; when it fires, {@code RummyEngineService} auto-plays the turn
 * (draw from closed deck, discard highest-value unmatched card, or drop).
 * <p>
 * Each turn change must call {@link #schedule} again (which implicitly
 * cancels any previous pending timeout for that room) to reset the clock.
 */
@Slf4j
@Component
public class TurnManager {

    private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(
            Math.max(2, Runtime.getRuntime().availableProcessors() / 2),
            daemonThreadFactory()
    );

    private final Map<String, ScheduledFuture<?>> pendingTimeouts = new ConcurrentHashMap<>();

    public void schedule(String roomCode, int timeoutSeconds, Runnable onTimeout) {
        cancel(roomCode);
        ScheduledFuture<?> future = scheduler.schedule(() -> {
            pendingTimeouts.remove(roomCode);
            try {
                onTimeout.run();
            } catch (Exception ex) {
                log.error("Turn timeout handler failed for room={}", roomCode, ex);
            }
        }, timeoutSeconds, TimeUnit.SECONDS);
        pendingTimeouts.put(roomCode, future);
    }

    public void cancel(String roomCode) {
        ScheduledFuture<?> existing = pendingTimeouts.remove(roomCode);
        if (existing != null) {
            existing.cancel(false);
        }
    }

    @PreDestroy
    public void shutdown() {
        scheduler.shutdownNow();
    }

    private static ThreadFactory daemonThreadFactory() {
        AtomicInteger counter = new AtomicInteger();
        return runnable -> {
            Thread thread = new Thread(runnable, "turn-timeout-" + counter.incrementAndGet());
            thread.setDaemon(true);
            return thread;
        };
    }
}
