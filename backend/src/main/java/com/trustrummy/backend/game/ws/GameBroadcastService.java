package com.trustrummy.backend.game.ws;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Registry of live WebSocket sessions per room, and the single choke
 * point through which every outbound {@link GameEvent} is sent. Kept as
 * its own component (rather than living inside {@code GameWebSocketHandler}
 * or {@code RummyEngineService}) so both can depend on it without a
 * circular dependency: the handler registers/unregisters sessions as
 * players connect/disconnect, and the engine broadcasts state changes
 * (including from timer-driven auto-play, with no WebSocket message
 * triggering it).
 */
@Slf4j
@Component
public class GameBroadcastService {

    private final ObjectMapper objectMapper = new ObjectMapper();

    /** roomCode -> (userId -> live session). */
    private final Map<String, Map<Long, WebSocketSession>> roomSessions = new ConcurrentHashMap<>();

    /**
     * roomCode -> (userId -> instant they were last seen disconnected).
     * Populated on {@link #unregister}, cleared on the next successful
     * {@link #register}. Consulted by the scheduled lifecycle reaper
     * ({@code RoomLifecycleService}) to forfeit a seat that has been gone
     * longer than the reconnect grace period, instead of leaving the rest
     * of the table waiting on it forever.
     */
    private final Map<String, Map<Long, Instant>> disconnectedSince = new ConcurrentHashMap<>();

    public void register(String roomCode, Long userId, WebSocketSession session) {
        roomSessions.computeIfAbsent(roomCode, r -> new ConcurrentHashMap<>()).put(userId, session);
        Map<Long, Instant> disconnects = disconnectedSince.get(roomCode);
        if (disconnects != null) {
            disconnects.remove(userId);
        }
    }

    public void unregister(String roomCode, Long userId) {
        Map<Long, WebSocketSession> sessions = roomSessions.get(roomCode);
        if (sessions != null) {
            sessions.remove(userId);
            if (sessions.isEmpty()) {
                roomSessions.remove(roomCode);
            }
        }
        disconnectedSince.computeIfAbsent(roomCode, r -> new ConcurrentHashMap<>()).put(userId, Instant.now());
    }

    /** How long ago this user's session in this room was last torn down, if it's currently disconnected. */
    public Optional<Instant> disconnectedSince(String roomCode, Long userId) {
        Map<Long, Instant> disconnects = disconnectedSince.get(roomCode);
        return disconnects == null ? Optional.empty() : Optional.ofNullable(disconnects.get(userId));
    }

    /** Drops all tracked state for a room once it's fully torn down (cancelled/disbanded), to avoid leaking memory. */
    public void clearRoom(String roomCode) {
        roomSessions.remove(roomCode);
        disconnectedSince.remove(roomCode);
    }

    public void sendTo(String roomCode, Long userId, GameEvent event) {
        Map<Long, WebSocketSession> sessions = roomSessions.get(roomCode);
        if (sessions == null) {
            return;
        }
        WebSocketSession session = sessions.get(userId);
        if (session != null) {
            send(session, event);
        }
    }

    /** Sends the identical event to every connected player in the room. */
    public void broadcast(String roomCode, GameEvent event) {
        Map<Long, WebSocketSession> sessions = roomSessions.get(roomCode);
        if (sessions == null) {
            return;
        }
        for (WebSocketSession session : sessions.values()) {
            send(session, event);
        }
    }

    /**
     * Sends a per-recipient event built by {@code eventFactory}. This is how
     * opponent hands stay obfuscated: the factory is called once per
     * connected userId and can build a different payload for the acting
     * player (full hand) vs everyone else (hand size only).
     */
    public void broadcastPersonalized(String roomCode, Function<Long, GameEvent> eventFactory) {
        Map<Long, WebSocketSession> sessions = roomSessions.get(roomCode);
        if (sessions == null) {
            return;
        }
        for (Map.Entry<Long, WebSocketSession> entry : sessions.entrySet()) {
            GameEvent event = eventFactory.apply(entry.getKey());
            if (event != null) {
                send(entry.getValue(), event);
            }
        }
    }

    public int connectedCount(String roomCode) {
        Map<Long, WebSocketSession> sessions = roomSessions.get(roomCode);
        return sessions == null ? 0 : sessions.size();
    }

    private void send(WebSocketSession session, GameEvent event) {
        try {
            if (session.isOpen()) {
                session.sendMessage(new TextMessage(objectMapper.writeValueAsString(event)));
            }
        } catch (Exception ex) {
            log.error("Failed to send game event {}", event.getType(), ex);
        }
    }
}
