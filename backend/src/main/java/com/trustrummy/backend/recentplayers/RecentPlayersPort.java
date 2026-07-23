package com.trustrummy.backend.recentplayers;

import java.time.Instant;
import java.util.Collection;

/**
 * Persistence hook used when a match is recorded as COMPLETED.
 */
public interface RecentPlayersPort {

    void recordEncounters(Collection<Long> participantUserIds, Long roomId, String roomCode, Instant playedAt);
}
