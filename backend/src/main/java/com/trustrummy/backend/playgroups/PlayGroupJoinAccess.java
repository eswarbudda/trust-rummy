package com.trustrummy.backend.playgroups;

import com.trustrummy.backend.rooms.GroupRoomAccessPort;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class PlayGroupJoinAccess implements GroupRoomAccessPort {

    private final PlayGroupMemberRepository memberRepository;

    @Override
    public boolean isActiveMember(long groupId, long userId) {
        return memberRepository.existsByGroupIdAndUserIdAndStatus(
                groupId, userId, PlayGroupMemberStatus.ACTIVE);
    }
}
