package com.trustrummy.backend.invitations;

import java.time.Instant;
import java.util.UUID;

public record InvitationView(
        UUID id,
        long roomId,
        String roomCode,
        Long groupId,
        long inviterId,
        String inviterUsername,
        long inviteeId,
        String inviteeUsername,
        String inviteeDisplayName,
        InvitationStatus status,
        Instant expiresAt,
        Instant createdAt,
        Instant respondedAt
) {
}
