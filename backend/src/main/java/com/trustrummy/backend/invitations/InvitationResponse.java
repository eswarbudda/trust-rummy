package com.trustrummy.backend.invitations;

import java.time.Instant;
import java.util.UUID;

public record InvitationResponse(
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
    public static InvitationResponse from(InvitationView view) {
        return new InvitationResponse(
                view.id(),
                view.roomId(),
                view.roomCode(),
                view.groupId(),
                view.inviterId(),
                view.inviterUsername(),
                view.inviteeId(),
                view.inviteeUsername(),
                view.inviteeDisplayName(),
                view.status(),
                view.expiresAt(),
                view.createdAt(),
                view.respondedAt()
        );
    }
}
