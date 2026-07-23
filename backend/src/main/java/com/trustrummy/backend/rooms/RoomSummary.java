package com.trustrummy.backend.rooms;

/**
 * Room snapshot exposed through {@link RoomPort} — no JPA entity leakage.
 */
public record RoomSummary(
        long id,
        String roomCode,
        String status,
        long createdByUserId,
        String createdByUsername,
        int maxPlayers,
        String name
) {
    public boolean isWaiting() {
        return "WAITING".equals(status);
    }
}
