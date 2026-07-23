package com.trustrummy.backend.friends;

/**
 * Command port used by Recent Players ("Send Friend Request") and the Friends REST API.
 */
public interface FriendsCommandPort {

    FriendshipView sendRequestByUsername(long requesterId, String username);

    FriendshipView sendRequestByUserId(long requesterId, long addresseeId);
}
