package com.trustrummy.backend.presence;

import org.springframework.web.socket.WebSocketSession;

/**
 * Holds live {@code /ws/user} sessions so other modules (e.g. notifications)
 * can push frames without depending on the WebSocket handler class.
 */
public interface UserSessionRegistry {

    void register(long userId, String sessionId, WebSocketSession session);

    void unregister(long userId, String sessionId);

    /**
     * Sends {@code jsonText} to every open session for {@code userId}.
     *
     * @return {@code true} if at least one session received the frame
     */
    boolean publish(long userId, String jsonText);
}
