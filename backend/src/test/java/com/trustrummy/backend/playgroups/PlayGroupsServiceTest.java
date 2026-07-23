package com.trustrummy.backend.playgroups;

import com.trustrummy.backend.exception.ForbiddenOperationException;
import com.trustrummy.backend.friends.FriendPort;
import com.trustrummy.backend.users.UserLookupPort;
import com.trustrummy.backend.users.UserSummary;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PlayGroupsServiceTest {

    @Mock
    private PlayGroupRepository groupRepository;
    @Mock
    private PlayGroupMemberRepository memberRepository;
    @Mock
    private UserLookupPort userLookupPort;
    @Mock
    private FriendPort friendPort;
    @Mock
    private com.trustrummy.backend.rooms.RoomPort roomPort;
    @Mock
    private com.trustrummy.backend.invitations.InvitationPort invitationPort;

    private PlayGroupsService service;

    @BeforeEach
    void setUp() {
        service = new PlayGroupsService(
                groupRepository, memberRepository, userLookupPort, friendPort, roomPort, invitationPort);
    }

    @Test
    void createPersistsGroupAndOwnerMembership() {
        when(userLookupPort.findById(1L)).thenReturn(Optional.of(new UserSummary(1L, "alice", "Alice")));
        when(groupRepository.save(any())).thenAnswer(inv -> {
            PlayGroupEntity g = inv.getArgument(0);
            g.setId(10L);
            g.setCreatedAt(Instant.now());
            g.setUpdatedAt(Instant.now());
            return g;
        });
        when(memberRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(memberRepository.countByGroupIdAndStatus(10L, PlayGroupMemberStatus.ACTIVE)).thenReturn(1L);
        when(memberRepository.findByGroupIdAndStatus(10L, PlayGroupMemberStatus.ACTIVE))
                .thenReturn(List.of(PlayGroupMemberEntity.builder()
                        .groupId(10L)
                        .userId(1L)
                        .role(PlayGroupMemberRole.OWNER)
                        .status(PlayGroupMemberStatus.ACTIVE)
                        .joinedAt(Instant.now())
                        .build()));
        when(userLookupPort.findByIds(List.of(1L)))
                .thenReturn(Map.of(1L, new UserSummary(1L, "alice", "Alice")));

        PlayGroupResponse response = service.create(1L, "Friday Night", 8);

        assertThat(response.id()).isEqualTo(10L);
        assertThat(response.name()).isEqualTo("Friday Night");
        assertThat(response.memberCount()).isEqualTo(1);
        ArgumentCaptor<PlayGroupMemberEntity> member = ArgumentCaptor.forClass(PlayGroupMemberEntity.class);
        verify(memberRepository).save(member.capture());
        assertThat(member.getValue().getRole()).isEqualTo(PlayGroupMemberRole.OWNER);
    }

    @Test
    void addMemberRequiresFriendship() {
        PlayGroupEntity group = activeGroup(10L, 1L);
        when(groupRepository.findById(10L)).thenReturn(Optional.of(group));
        when(userLookupPort.findById(2L)).thenReturn(Optional.of(new UserSummary(2L, "bob", "Bob")));
        when(friendPort.areFriends(1L, 2L)).thenReturn(false);

        assertThatThrownBy(() -> service.addMember(1L, 10L, 2L, null))
                .isInstanceOf(ForbiddenOperationException.class)
                .hasMessageContaining("friends");
        verify(memberRepository, never()).save(any());
    }

    @Test
    void addMemberSucceedsForAcceptedFriend() {
        PlayGroupEntity group = activeGroup(10L, 1L);
        when(groupRepository.findById(10L)).thenReturn(Optional.of(group));
        when(userLookupPort.findById(1L)).thenReturn(Optional.of(new UserSummary(1L, "alice", "Alice")));
        when(userLookupPort.findById(2L)).thenReturn(Optional.of(new UserSummary(2L, "bob", "Bob")));
        when(friendPort.areFriends(1L, 2L)).thenReturn(true);
        when(memberRepository.countByGroupIdAndStatus(10L, PlayGroupMemberStatus.ACTIVE)).thenReturn(1L);
        when(memberRepository.findByGroupIdAndUserId(10L, 2L)).thenReturn(Optional.empty());
        when(memberRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(memberRepository.findByGroupIdAndStatus(10L, PlayGroupMemberStatus.ACTIVE))
                .thenReturn(List.of(
                        PlayGroupMemberEntity.builder()
                                .groupId(10L).userId(1L).role(PlayGroupMemberRole.OWNER)
                                .status(PlayGroupMemberStatus.ACTIVE).joinedAt(Instant.now()).build(),
                        PlayGroupMemberEntity.builder()
                                .groupId(10L).userId(2L).role(PlayGroupMemberRole.MEMBER)
                                .status(PlayGroupMemberStatus.ACTIVE).joinedAt(Instant.now()).build()
                ));
        when(userLookupPort.findByIds(eq(List.of(1L, 2L))))
                .thenReturn(Map.of(
                        1L, new UserSummary(1L, "alice", "Alice"),
                        2L, new UserSummary(2L, "bob", "Bob")
                ));

        PlayGroupResponse response = service.addMember(1L, 10L, 2L, null);

        assertThat(response.memberCount()).isEqualTo(2);
        verify(memberRepository).save(any(PlayGroupMemberEntity.class));
    }

    @Test
    void nonOwnerCannotRename() {
        PlayGroupEntity group = activeGroup(10L, 1L);
        when(groupRepository.findById(10L)).thenReturn(Optional.of(group));

        assertThatThrownBy(() -> service.rename(2L, 10L, "Hack"))
                .isInstanceOf(ForbiddenOperationException.class);
    }

    private static PlayGroupEntity activeGroup(long id, long ownerId) {
        return PlayGroupEntity.builder()
                .id(id)
                .name("Group")
                .ownerId(ownerId)
                .status(PlayGroupStatus.ACTIVE)
                .type(PlayGroupType.GROUP)
                .maxMembers(20)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
    }
}
