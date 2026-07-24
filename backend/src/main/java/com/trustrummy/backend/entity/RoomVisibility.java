package com.trustrummy.backend.entity;

/**
 * Who may discover/join a waiting room.
 * <ul>
 *   <li>{@link #PUBLIC} — listed in lobby; anyone may join by code</li>
 *   <li>{@link #PRIVATE} — not listed; join requires a game invitation</li>
 *   <li>{@link #GROUP_ONLY} — not listed; join requires active play-group membership
 *       (or a game invitation into that room)</li>
 * </ul>
 */
public enum RoomVisibility {
    PUBLIC,
    PRIVATE,
    GROUP_ONLY
}
