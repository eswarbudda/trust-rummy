package com.trustrummy.backend.game.model;

/**
 * Lifecycle of the overall multi-deal match held in memory for a room.
 * Distinct from the persisted {@code entity.RoomStatus}, which tracks the
 * room record itself rather than deal-by-deal match progress.
 */
public enum MatchStatus {
    WAITING,
    IN_PROGRESS,
    /** Deal scored; waiting for Start Next Deal or the auto-start countdown. */
    BETWEEN_DEALS,
    COMPLETED
}
