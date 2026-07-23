package com.trustrummy.backend.friends;

/**
 * Read port for Play Groups and other consumers that need friendship checks.
 */
public interface FriendPort {

    boolean areFriends(long userId, long otherUserId);

    /** Throws {@link org.springframework.web.server.ResponseStatusException} 403 if not ACCEPTED friends. */
    void requireFriends(long userId, long otherUserId);
}
