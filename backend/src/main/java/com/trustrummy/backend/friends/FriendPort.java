package com.trustrummy.backend.friends;

/**
 * Query port for Play Groups and other consumers that need friendship checks.
 * Consumers enforce business rules (e.g. require ACCEPTED) themselves via {@link #areFriends}.
 */
public interface FriendPort {

    boolean areFriends(long userId, long otherUserId);
}
