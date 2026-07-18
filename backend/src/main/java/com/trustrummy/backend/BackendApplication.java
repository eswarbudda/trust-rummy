package com.trustrummy.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * {@code @EnableAsync}: durable game persistence (move log / results) runs off the WebSocket hot path.
 * {@code @EnableScheduling}: powers {@code RoomLifecycleService}'s periodic stale-room / disconnected-player reaper.
 */
@EnableAsync
@EnableScheduling
@SpringBootApplication
public class BackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(BackendApplication.class, args);
    }
}
