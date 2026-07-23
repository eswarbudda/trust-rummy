package com.trustrummy.backend.recentplayers;

import com.trustrummy.backend.invitations.InvitationResponse;

public record InviteAgainResponse(
        long roomId,
        String roomCode,
        long opponentUserId,
        InvitationResponse invitation
) {
}
