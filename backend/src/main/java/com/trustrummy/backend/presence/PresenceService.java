package com.trustrummy.backend.presence;

import java.util.Collection;
import java.util.Set;

/**
 * Presence port used by social modules. Implementations must be safe for
 * concurrent WebSocket connect/disconnect/heartbeat traffic.
 * <p>
 * MVP: {@link InMemoryPresenceService}. Future: Redis-backed impl with the
 * same contract (no business-logic changes).
 */
public interface PresenceService {

    void onConnect(long userId, String sessionId);

    void onDisconnect(long userId, String sessionId);

    /** Optional keep-alive; in-memory MVP treats this as a no-op beyond logging. */
    void heartbeat(long userId, String sessionId);

    boolean isOnline(long userId);

    PresenceStatus getStatus(long userId);

    /** Returns the subset of {@code userIds} that currently have ≥1 session. */
    Set<Long> filterOnline(Collection<Long> userIds);

    /** Active {@code /ws/user} session count for diagnostics / {@code /presence/me}. */
    int sessionCount(long userId);
}
