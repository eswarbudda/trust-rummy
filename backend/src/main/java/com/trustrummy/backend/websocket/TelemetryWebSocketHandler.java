package com.trustrummy.backend.websocket;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Minimal, self-contained real-time telemetry endpoint.
 * <p>
 * Its sole purpose is to prove end-to-end connectivity between the Flutter
 * client and the Spring Boot server (through the JWT-gated handshake) as
 * early as possible in the project, before any real game logic exists:
 * connect -> server pushes a heartbeat "pong"/echo every message -> client
 * renders live round-trip latency in the UI.
 */
@Slf4j
public class TelemetryWebSocketHandler extends TextWebSocketHandler {

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final Map<String, WebSocketSession> activeSessions = new ConcurrentHashMap<>();
    private final AtomicLong messageCounter = new AtomicLong();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        activeSessions.put(session.getId(), session);
        String username = (String) session.getAttributes().getOrDefault("username", "anonymous");
        log.info("Telemetry socket connected: session={} user={}", session.getId(), username);
        sendJson(session, Map.of(
                "type", "WELCOME",
                "message", "Trust Rummy telemetry channel connected",
                "user", username,
                "serverTime", Instant.now().toString(),
                "activeConnections", activeSessions.size()
        ));
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) {
        long seq = messageCounter.incrementAndGet();
        String username = (String) session.getAttributes().getOrDefault("username", "anonymous");
        log.debug("Telemetry message #{} from user={}: {}", seq, username, message.getPayload());

        sendJson(session, Map.of(
                "type", "PONG",
                "sequence", seq,
                "echo", message.getPayload(),
                "serverTime", Instant.now().toString()
        ));
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        activeSessions.remove(session.getId());
        log.info("Telemetry socket closed: session={} status={}", session.getId(), status);
    }

    private void sendJson(WebSocketSession session, Object payload) {
        try {
            if (session.isOpen()) {
                session.sendMessage(new TextMessage(objectMapper.writeValueAsString(payload)));
            }
        } catch (Exception ex) {
            log.error("Failed to send telemetry message", ex);
        }
    }
}
