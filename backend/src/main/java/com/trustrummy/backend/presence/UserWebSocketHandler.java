package com.trustrummy.backend.presence;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.time.Instant;
import java.util.Map;

/**
 * Authenticated user channel ({@code /ws/user}) that drives {@link PresenceService}.
 * Future social modules deliver notifications on this socket; this handler only
 * owns connect / heartbeat / disconnect for MVP presence.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class UserWebSocketHandler extends TextWebSocketHandler {

    private static final String USER_ID_ATTR = "userId";

    private final PresenceService presenceService;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        Long userId = resolveUserId(session);
        if (userId == null) {
            log.warn("User socket rejected: missing userId from handshake");
            closeQuietly(session, CloseStatus.NOT_ACCEPTABLE);
            return;
        }

        presenceService.onConnect(userId, session.getId());
        String username = String.valueOf(session.getAttributes().getOrDefault("username", ""));
        log.info("User socket connected: user={} userId={} session={}", username, userId, session.getId());

        sendJson(session, Map.of(
                "type", "PRESENCE",
                "status", PresenceStatus.ONLINE.name(),
                "sessionId", session.getId(),
                "serverTime", Instant.now().toString()
        ));
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) {
        Long userId = resolveUserId(session);
        if (userId == null) {
            return;
        }

        try {
            JsonNode root = objectMapper.readTree(message.getPayload());
            String type = root.path("type").asText("");
            if ("HEARTBEAT".equalsIgnoreCase(type) || "PING".equalsIgnoreCase(type)) {
                presenceService.heartbeat(userId, session.getId());
                sendJson(session, Map.of(
                        "type", "HEARTBEAT_ACK",
                        "status", PresenceStatus.ONLINE.name(),
                        "serverTime", Instant.now().toString()
                ));
                return;
            }
            sendJson(session, Map.of(
                    "type", "ERROR",
                    "message", "Unknown action type: " + type
            ));
        } catch (Exception ex) {
            log.warn("Malformed user-socket payload from userId={}: {}", userId, message.getPayload());
            sendJson(session, Map.of(
                    "type", "ERROR",
                    "message", "Malformed action payload"
            ));
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        Long userId = resolveUserId(session);
        if (userId != null) {
            presenceService.onDisconnect(userId, session.getId());
            log.info("User socket closed: userId={} session={} status={}", userId, session.getId(), status);
        }
    }

    private Long resolveUserId(WebSocketSession session) {
        Object attr = session.getAttributes().get(USER_ID_ATTR);
        if (attr instanceof Long longId) {
            return longId;
        }
        if (attr instanceof Number number) {
            return number.longValue();
        }
        return null;
    }

    private void sendJson(WebSocketSession session, Object payload) {
        try {
            if (session.isOpen()) {
                session.sendMessage(new TextMessage(objectMapper.writeValueAsString(payload)));
            }
        } catch (Exception ex) {
            log.warn("Failed to send on /ws/user session={}", session.getId(), ex);
        }
    }

    private void closeQuietly(WebSocketSession session, CloseStatus status) {
        try {
            session.close(status);
        } catch (Exception ignored) {
            // ignore
        }
    }
}
