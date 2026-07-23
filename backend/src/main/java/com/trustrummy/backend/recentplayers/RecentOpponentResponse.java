package com.trustrummy.backend.recentplayers;

import java.time.Instant;

public record RecentOpponentResponse(
        long userId,
        String username,
        String displayName,
        boolean online,
        boolean alreadyFriends,
        int matchCount,
        Instant lastPlayedAt,
        String lastRoomCode
) {
}
