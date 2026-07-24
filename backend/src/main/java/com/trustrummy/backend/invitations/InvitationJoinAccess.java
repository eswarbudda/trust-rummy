package com.trustrummy.backend.invitations;

import com.trustrummy.backend.rooms.PrivateRoomInvitePort;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.EnumSet;

@Component
@RequiredArgsConstructor
public class InvitationJoinAccess implements PrivateRoomInvitePort {

    private final GameInvitationRepository invitationRepository;

    @Override
    public boolean hasJoinableInvite(long roomId, long userId) {
        return invitationRepository.existsByRoomIdAndInviteeIdAndStatusIn(
                roomId,
                userId,
                EnumSet.of(InvitationStatus.PENDING, InvitationStatus.ACCEPTED)
        );
    }
}
