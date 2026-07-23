package com.trustrummy.backend.presence;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@Component
public class InMemoryUserSessionRegistry implements UserSessionRegistry {

    private final ConcurrentHashMap<Long, ConcurrentHashMap<String, WebSocketSession>> sessions =
            new ConcurrentHashMap<>();

    @Override
    public void register(long userId, String sessionId, WebSocketSession session) {
        sessions.computeIfAbsent(userId, id -> new ConcurrentHashMap<>()).put(sessionId, session);
    }

    @Override
    public void unregister(long userId, String sessionId) {
        sessions.computeIfPresent(userId, (id, map) -> {
            map.remove(sessionId);
            return map.isEmpty() ? null : map;
        });
    }

    @Override
    public boolean publish(long userId, String jsonText) {
        Map<String, WebSocketSession> map = sessions.get(userId);
        if (map == null || map.isEmpty()) {
            return false;
        }
        boolean any = false;
        TextMessage message = new TextMessage(jsonText);
        for (WebSocketSession session : map.values()) {
            if (session == null || !session.isOpen()) {
                continue;
            }
            try {
                synchronized (session) {
                    session.sendMessage(message);
                }
                any = true;
            } catch (IOException | IllegalStateException ex) {
                log.debug("Failed to publish to userId={} session={}: {}", userId, session.getId(), ex.toString());
            }
        }
        return any;
    }
}
