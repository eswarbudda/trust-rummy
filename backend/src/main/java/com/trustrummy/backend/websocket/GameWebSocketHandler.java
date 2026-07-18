package com.trustrummy.backend.websocket;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.trustrummy.backend.gamestate.LiveGameState;
import com.trustrummy.backend.service.GameStateService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.util.Map;

/**
 * Stub for the real-time gameplay channel. Full move validation / turn
 * engine lands in a later phase; for now this wires the socket to the
 * in-memory {@link GameStateService} so room state lookups never hit the
 * database on the hot path.
 */
@Slf4j
@RequiredArgsConstructor
public class GameWebSocketHandler extends TextWebSocketHandler {

    private static final String ROOM_CODE_ATTR = "roomCode";

    private final GameStateService gameStateService;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        String roomCode = extractRoomCode(session);
        String username = (String) session.getAttributes().getOrDefault("username", "anonymous");

        LiveGameState state = gameStateService.getOrCreate(roomCode);
        log.info("Game socket connected: user={} room={} activeRooms={}",
                username, roomCode, gameStateService.activeRoomCount());

        sendJson(session, Map.of(
                "type", "ROOM_STATE",
                "roomCode", roomCode,
                "status", state.getStatus(),
                "currentTurnUserId", String.valueOf(state.currentTurnUserId())
        ));
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) {
        // Move parsing / validation / broadcast is implemented in a later phase.
        log.debug("Game message received (unhandled in phase 1): {}", message.getPayload());
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        String roomCode = extractRoomCode(session);
        log.info("Game socket closed: room={} status={}", roomCode, status);
    }

    private String extractRoomCode(WebSocketSession session) {
        Object attr = session.getAttributes().get(ROOM_CODE_ATTR);
        if (attr != null) {
            return attr.toString();
        }
        String uri = String.valueOf(session.getUri());
        String[] parts = uri.split("/");
        return parts[parts.length - 1];
    }

    private void sendJson(WebSocketSession session, Object payload) {
        try {
            if (session.isOpen()) {
                session.sendMessage(new TextMessage(objectMapper.writeValueAsString(payload)));
            }
        } catch (Exception ex) {
            log.error("Failed to send game state message", ex);
        }
    }
}
