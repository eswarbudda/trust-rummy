package com.trustrummy.backend.friends;

import java.time.Instant;

public record FriendRequestResponse(
        long friendshipId,
        String direction,
        long otherUserId,
        String otherUsername,
        String otherDisplayName,
        Instant createdAt
) {
}
