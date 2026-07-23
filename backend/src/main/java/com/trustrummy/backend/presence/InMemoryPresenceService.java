package com.trustrummy.backend.presence;

import org.springframework.stereotype.Service;

import java.util.Collection;
import java.util.Collections;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Single-node presence: {@code userId → set(sessionId)}.
 * Multi-device: user stays ONLINE until the last session disconnects.
 */
@Service
public class InMemoryPresenceService implements PresenceService {

    private final ConcurrentHashMap<Long, Set<String>> sessionsByUser = new ConcurrentHashMap<>();

    @Override
    public void onConnect(long userId, String sessionId) {
        sessionsByUser.compute(userId, (id, existing) -> {
            Set<String> next = existing != null ? existing : ConcurrentHashMap.newKeySet();
            next.add(sessionId);
            return next;
        });
    }

    @Override
    public void onDisconnect(long userId, String sessionId) {
        sessionsByUser.computeIfPresent(userId, (id, existing) -> {
            existing.remove(sessionId);
            return existing.isEmpty() ? null : existing;
        });
    }

    @Override
    public void heartbeat(long userId, String sessionId) {
        Set<String> sessions = sessionsByUser.get(userId);
        if (sessions == null || !sessions.contains(sessionId)) {
            // Re-bind if the client heartbeats after a missed connect race.
            onConnect(userId, sessionId);
        }
    }

    @Override
    public boolean isOnline(long userId) {
        Set<String> sessions = sessionsByUser.get(userId);
        return sessions != null && !sessions.isEmpty();
    }

    @Override
    public PresenceStatus getStatus(long userId) {
        return isOnline(userId) ? PresenceStatus.ONLINE : PresenceStatus.OFFLINE;
    }

    @Override
    public Set<Long> filterOnline(Collection<Long> userIds) {
        if (userIds == null || userIds.isEmpty()) {
            return Set.of();
        }
        Set<Long> online = new HashSet<>();
        for (Long userId : userIds) {
            if (userId != null && isOnline(userId)) {
                online.add(userId);
            }
        }
        return Collections.unmodifiableSet(online);
    }

    @Override
    public int sessionCount(long userId) {
        Set<String> sessions = sessionsByUser.get(userId);
        return sessions == null ? 0 : sessions.size();
    }

    /** Test helper — not part of the public port contract. */
    Map<Long, Set<String>> snapshotForTests() {
        return Map.copyOf(sessionsByUser);
    }
}
