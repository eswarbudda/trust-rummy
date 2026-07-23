package com.trustrummy.backend.playgroups;

import java.time.Instant;

public record PlayGroupMemberResponse(
        long userId,
        String username,
        String displayName,
        PlayGroupMemberRole role,
        PlayGroupMemberStatus status,
        Instant joinedAt
) {
}
