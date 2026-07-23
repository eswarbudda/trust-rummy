package com.trustrummy.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

import java.util.TimeZone;

/**
 * {@code @EnableAsync}: durable game persistence (move log / results) runs off the WebSocket hot path.
 * {@code @EnableScheduling}: powers {@code RoomLifecycleService}'s periodic stale-room / disconnected-player reaper.
 */
@EnableAsync
@EnableScheduling
@SpringBootApplication
public class BackendApplication {

    static {
        // PostgreSQL rejects the legacy JVM id "Asia/Calcutta". Force UTC before
        // any datasource/Flyway connection is opened (tests + spring-boot:run).
        TimeZone.setDefault(TimeZone.getTimeZone("UTC"));
        System.setProperty("user.timezone", "UTC");
    }

    public static void main(String[] args) {
        SpringApplication.run(BackendApplication.class, args);
    }
}
