package com.trustrummy.backend.presence;

/**
 * Coarse presence derived from active {@code /ws/user} sessions.
 * No persistent table — Redis-backed impl can replace {@link InMemoryPresenceService}
 * without changing callers.
 */
public enum PresenceStatus {
    ONLINE,
    OFFLINE
}
