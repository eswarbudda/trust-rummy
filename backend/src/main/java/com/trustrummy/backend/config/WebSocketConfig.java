package com.trustrummy.backend.config;

import com.trustrummy.backend.presence.UserWebSocketHandler;
import com.trustrummy.backend.repository.UserRepository;
import com.trustrummy.backend.security.JwtHandshakeInterceptor;
import com.trustrummy.backend.security.JwtTokenUtil;
import com.trustrummy.backend.websocket.GameWebSocketHandler;
import com.trustrummy.backend.websocket.TelemetryWebSocketHandler;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistration;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;
import org.springframework.web.socket.server.standard.ServletServerContainerFactoryBean;

/**
 * Wires raw (non-STOMP) WebSocket endpoints.
 * <p>
 * Rule 2: every endpoint registered here goes through {@link JwtHandshakeInterceptor},
 * which validates the JWT during the HTTP upgrade, before the socket is accepted.
 * Rule 4: {@link #createWebSocketContainer()} stubs out hard payload-size ceilings
 * so a malicious/buggy client can never send an oversized frame into the server.
 */
@Configuration
@EnableWebSocket
@RequiredArgsConstructor
public class WebSocketConfig implements WebSocketConfigurer {

    private static final int MAX_TEXT_MESSAGE_BUFFER_SIZE = 64 * 1024; // 64 KB
    private static final int MAX_BINARY_MESSAGE_BUFFER_SIZE = 64 * 1024; // 64 KB
    private static final int MAX_SESSION_IDLE_TIMEOUT_MS = 5 * 60 * 1000; // 5 minutes

    private final JwtTokenUtil jwtTokenUtil;
    private final UserRepository userRepository;
    private final GameWebSocketHandler gameWebSocketHandler;
    private final UserWebSocketHandler userWebSocketHandler;

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        WebSocketHandlerRegistration telemetryRegistration = registry
                .addHandler(telemetryWebSocketHandler(), "/ws/telemetry")
                .addInterceptors(jwtHandshakeInterceptor());
        applyDevCors(telemetryRegistration);

        WebSocketHandlerRegistration gameRegistration = registry
                .addHandler(gameWebSocketHandler, "/ws/game/{roomCode}")
                .addInterceptors(jwtHandshakeInterceptor());
        applyDevCors(gameRegistration);

        WebSocketHandlerRegistration userRegistration = registry
                .addHandler(userWebSocketHandler, "/ws/user")
                .addInterceptors(jwtHandshakeInterceptor());
        applyDevCors(userRegistration);
    }

    // Rule 3 (WebSocket variant): only allow explicit localhost/dev origins (any port) used by the REST CORS policy.
    private void applyDevCors(WebSocketHandlerRegistration registration) {
        registration.setAllowedOriginPatterns(
                "http://localhost:*",
                "http://127.0.0.1:*"
        );
    }

    @Bean
    public WebSocketHandler telemetryWebSocketHandler() {
        return new TelemetryWebSocketHandler();
    }

    @Bean
    public JwtHandshakeInterceptor jwtHandshakeInterceptor() {
        return new JwtHandshakeInterceptor(jwtTokenUtil, userRepository);
    }

    /**
     * Rule 4: Stubbed payload/session constraints for the underlying servlet
     * WebSocket container (Tomcat by default under spring-boot-starter-websocket).
     */
    @Bean
    public ServletServerContainerFactoryBean createWebSocketContainer() {
        ServletServerContainerFactoryBean container = new ServletServerContainerFactoryBean();
        container.setMaxTextMessageBufferSize(MAX_TEXT_MESSAGE_BUFFER_SIZE);
        container.setMaxBinaryMessageBufferSize(MAX_BINARY_MESSAGE_BUFFER_SIZE);
        container.setMaxSessionIdleTimeout((long) MAX_SESSION_IDLE_TIMEOUT_MS);
        return container;
    }
}
