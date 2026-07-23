package com.trustrummy.backend.invitations;

import jakarta.validation.constraints.NotNull;

public record CreateRoomInvitationRequest(
        @NotNull Long userId
) {
}
