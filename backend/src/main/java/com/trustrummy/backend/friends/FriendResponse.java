package com.trustrummy.backend.friends;

import java.time.Instant;

public record FriendResponse(
        long friendshipId,
        long userId,
        String username,
        String displayName,
        boolean online,
        Instant friendsSince
) {
}
