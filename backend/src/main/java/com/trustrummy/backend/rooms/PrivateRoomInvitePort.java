package com.trustrummy.backend.rooms;

/**
 * Whether a user has a joinable game invitation for a PRIVATE (or gated) room.
 * Implemented in the invitations module against {@code game_invitations} only.
 */
public interface PrivateRoomInvitePort {

    boolean hasJoinableInvite(long roomId, long userId);
}
