package com.trustrummy.backend.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.TaskExecutor;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

/**
 * Dedicated, strictly single-threaded executor for {@code GamePersistenceService}.
 * <p>
 * Every {@code @Async} call it makes (recordMatchStart -> recordMove* ->
 * recordMatchEnd, for a given room) is fired from the same synchronous
 * engine call chain in {@code RummyEngineService}, always in that
 * chronological order. Without a dedicated executor, {@code @Async} methods
 * fall back to Spring Boot's shared {@code applicationTaskExecutor}, which
 * has more than one worker thread — so two calls submitted back-to-back can
 * be picked up by two different idle threads and race, with no guarantee
 * the one submitted first actually finishes first. In practice this let
 * {@code recordMatchEnd} run (and silently no-op, finding no session row
 * yet) before {@code recordMatchStart}'s insert had committed for
 * fast-ending matches, permanently stranding the {@code GameSession} at
 * {@code SessionStatus.ACTIVE}. A single worker thread makes the queue a
 * strict FIFO, so submission order is always preserved, while callers still
 * get the non-blocking, fire-and-forget behaviour they rely on.
 */
@Configuration
public class AsyncConfig {

    @Bean
    public TaskExecutor gamePersistenceExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(1);
        executor.setMaxPoolSize(1);
        executor.setQueueCapacity(Integer.MAX_VALUE);
        executor.setThreadNamePrefix("game-persistence-");
        executor.initialize();
        return executor;
    }
}
