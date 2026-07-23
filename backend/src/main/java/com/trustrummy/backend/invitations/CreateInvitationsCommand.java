package com.trustrummy.backend.invitations;

import java.time.Instant;
import java.util.List;

public record CreateInvitationsCommand(
        long roomId,
        Long groupId,
        long inviterId,
        List<Long> inviteeIds,
        Instant expiresAt
) {
}
