package com.trustrummy.backend.playgroups;

import com.trustrummy.backend.invitations.InvitationResponse;

import java.util.List;

public record StartPlayGroupGameResponse(
        long roomId,
        String roomCode,
        Long groupId,
        String groupName,
        List<InvitationResponse> invitations
) {
}
