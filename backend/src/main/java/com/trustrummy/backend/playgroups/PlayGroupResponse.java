package com.trustrummy.backend.playgroups;

import java.time.Instant;
import java.util.List;

public record PlayGroupResponse(
        long id,
        String name,
        long ownerId,
        String ownerUsername,
        PlayGroupStatus status,
        PlayGroupType type,
        int maxMembers,
        int memberCount,
        Instant createdAt,
        Instant updatedAt,
        List<PlayGroupMemberResponse> members
) {
}
