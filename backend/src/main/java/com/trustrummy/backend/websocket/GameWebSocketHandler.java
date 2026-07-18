package com.trustrummy.backend.websocket;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.trustrummy.backend.entity.User;
import com.trustrummy.backend.game.ws.EventType;
import com.trustrummy.backend.game.ws.GameActionMessage;
import com.trustrummy.backend.game.ws.GameBroadcastService;
import com.trustrummy.backend.game.ws.GameEvent;
import com.trustrummy.backend.repository.UserRepository;
import com.trustrummy.backend.service.RummyEngineService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.util.Optional;

/**
 * Real-time gameplay channel ({@code /ws/game/{roomCode}}). Thin transport
 * layer only — all game rules live in {@link RummyEngineService}; this
 * class just:
 * <ol>
 *   <li>resolves the JWT-authenticated username (set by
 *       {@code JwtHandshakeInterceptor}) to a numeric userId,</li>
 *   <li>registers/unregisters the session with {@link GameBroadcastService}
 *       so the engine can broadcast to every player in the room (including
 *       from timer-driven auto-play, with no inbound message involved),</li>
 *   <li>deserializes inbound JSON into a {@link GameActionMessage} and
 *       hands it to the engine.</li>
 * </ol>
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class GameWebSocketHandler extends TextWebSocketHandler {

    private static final String ROOM_CODE_ATTR = "roomCode";
    private static final String USER_ID_ATTR = "userId";

    private final RummyEngineService rummyEngineService;
    private final GameBroadcastService broadcastService;
    private final UserRepository userRepository;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        String roomCode = extractRoomCode(session);
        String username = (String) session.getAttributes().getOrDefault("username", null);

        Optional<User> user = username != null ? userRepository.findByUsername(username) : Optional.empty();
        if (user.isEmpty()) {
            log.warn("Game socket rejected: unknown user for room={}", roomCode);
            closeQuietly(session, CloseStatus.NOT_ACCEPTABLE);
            return;
        }

        Long userId = user.get().getId();
        session.getAttributes().put(USER_ID_ATTR, userId);
        session.getAttributes().put(ROOM_CODE_ATTR, roomCode);

        broadcastService.register(roomCode, userId, session);
        log.info("Game socket connected: user={} room={}", username, roomCode);

        broadcastService.sendTo(roomCode, userId, rummyEngineService.buildSnapshotEventFor(roomCode, userId));
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) {
        String roomCode = (String) session.getAttributes().get(ROOM_CODE_ATTR);
        Long userId = (Long) session.getAttributes().get(USER_ID_ATTR);
        if (roomCode == null || userId == null) {
            // Never drop a message with zero client-visible feedback — every
            // other failure path below reports an ERROR event. Since this
            // session was never fully registered, we can't route through
            // GameBroadcastService (it looks up by roomCode+userId), so we
            // send directly on the raw session instead.
            log.warn("Game action dropped: session id={} has no roomCode/userId attributes (handshake never completed?)",
                    session.getId());
            sendDirect(session, GameEvent.of(EventType.ERROR)
                    .with("message", "Session not fully established — reconnect and try again"));
            return;
        }

        try {
            GameActionMessage action = objectMapper.readValue(message.getPayload(), GameActionMessage.class);
            if (action.getType() == null) {
                broadcastService.sendTo(roomCode, userId, GameEvent.of(EventType.ERROR).with("message", "Missing action type"));
                return;
            }
            rummyEngineService.handleAction(roomCode, userId, action);
        } catch (Exception ex) {
            log.warn("Malformed game action from user={}: {}", userId, message.getPayload(), ex);
            broadcastService.sendTo(roomCode, userId, GameEvent.of(EventType.ERROR).with("message", "Malformed action payload"));
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        String roomCode = (String) session.getAttributes().get(ROOM_CODE_ATTR);
        Long userId = (Long) session.getAttributes().get(USER_ID_ATTR);
        if (roomCode != null && userId != null) {
            broadcastService.unregister(roomCode, userId);
        }
        log.info("Game socket closed: room={} status={}", roomCode, status);
    }

    private String extractRoomCode(WebSocketSession session) {
        Object attr = session.getAttributes().get(ROOM_CODE_ATTR);
        if (attr != null) {
            return attr.toString();
        }
        String uri = String.valueOf(session.getUri());
        String[] parts = uri.split("[/?]");
        for (int i = 0; i < parts.length; i++) {
            if ("game".equals(parts[i]) && i + 1 < parts.length) {
                return parts[i + 1];
            }
        }
        return parts[parts.length - 1];
    }

    private void closeQuietly(WebSocketSession session, CloseStatus status) {
        try {
            session.close(status);
        } catch (Exception ex) {
            log.debug("Failed to close rejected game socket", ex);
        }
    }

    /** Sends straight to this session, bypassing {@link GameBroadcastService}'s roomCode+userId registry lookup. */
    private void sendDirect(WebSocketSession session, GameEvent event) {
        try {
            if (session.isOpen()) {
                session.sendMessage(new TextMessage(objectMapper.writeValueAsString(event)));
            }
        } catch (Exception ex) {
            log.error("Failed to send direct game event to unregistered session id={}", session.getId(), ex);
        }
    }
}
