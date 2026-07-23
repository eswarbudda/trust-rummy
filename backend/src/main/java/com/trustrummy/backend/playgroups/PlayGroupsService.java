package com.trustrummy.backend.playgroups;

import com.trustrummy.backend.exception.ForbiddenOperationException;
import com.trustrummy.backend.exception.ResourceNotFoundException;
import com.trustrummy.backend.friends.FriendPort;
import com.trustrummy.backend.game.model.GameType;
import com.trustrummy.backend.game.model.GameVariant;
import com.trustrummy.backend.invitations.CreateInvitationsCommand;
import com.trustrummy.backend.invitations.InvitationPort;
import com.trustrummy.backend.invitations.InvitationResponse;
import com.trustrummy.backend.invitations.InvitationView;
import com.trustrummy.backend.rooms.CreateWaitingRoomCommand;
import com.trustrummy.backend.rooms.RoomPort;
import com.trustrummy.backend.rooms.RoomSummary;
import com.trustrummy.backend.users.UserLookupPort;
import com.trustrummy.backend.users.UserSummary;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class PlayGroupsService {

    private final PlayGroupRepository groupRepository;
    private final PlayGroupMemberRepository memberRepository;
    private final UserLookupPort userLookupPort;
    private final FriendPort friendPort;
    private final RoomPort roomPort;
    private final InvitationPort invitationPort;

    @Transactional(readOnly = true)
    public List<PlayGroupResponse> listMyGroups(long userId) {
        return groupRepository.findActiveGroupsForUser(userId).stream()
                .map(g -> toResponse(g, false))
                .toList();
    }

    @Transactional(readOnly = true)
    public PlayGroupResponse getGroup(long userId, long groupId) {
        PlayGroupEntity group = requireActiveGroup(groupId);
        requireActiveMember(groupId, userId);
        return toResponse(group, true);
    }

    @Transactional
    public PlayGroupResponse create(long ownerId, String name, Integer maxMembers) {
        String trimmed = requireName(name);
        userLookupPort.findById(ownerId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        int max = maxMembers == null ? 20 : maxMembers;
        if (max < 2 || max > 50) {
            throw new IllegalArgumentException("maxMembers must be between 2 and 50");
        }

        PlayGroupEntity group = groupRepository.save(PlayGroupEntity.builder()
                .name(trimmed)
                .ownerId(ownerId)
                .status(PlayGroupStatus.ACTIVE)
                .type(PlayGroupType.GROUP)
                .maxMembers(max)
                .build());

        memberRepository.save(PlayGroupMemberEntity.builder()
                .groupId(group.getId())
                .userId(ownerId)
                .role(PlayGroupMemberRole.OWNER)
                .status(PlayGroupMemberStatus.ACTIVE)
                .addedById(ownerId)
                .build());

        return toResponse(group, true);
    }

    @Transactional
    public PlayGroupResponse rename(long userId, long groupId, String name) {
        PlayGroupEntity group = requireActiveGroup(groupId);
        requireOwner(group, userId);
        group.setName(requireName(name));
        return toResponse(groupRepository.save(group), true);
    }

    @Transactional
    public PlayGroupResponse softDelete(long userId, long groupId) {
        PlayGroupEntity group = requireActiveGroup(groupId);
        requireOwner(group, userId);
        group.setStatus(PlayGroupStatus.DELETED);
        group.setDeletedAt(Instant.now());
        return toResponse(groupRepository.save(group), false);
    }

    @Transactional
    public PlayGroupResponse addMember(long actorId, long groupId, Long targetUserId, String username) {
        PlayGroupEntity group = requireActiveGroup(groupId);
        requireOwner(group, actorId);

        UserSummary target = resolveUser(targetUserId, username);
        if (target.id() == actorId) {
            throw new IllegalArgumentException("Owner is already a member");
        }
        if (!friendPort.areFriends(actorId, target.id())) {
            throw new ForbiddenOperationException("Can only add accepted friends to a play group");
        }

        long activeCount = memberRepository.countByGroupIdAndStatus(groupId, PlayGroupMemberStatus.ACTIVE);
        if (activeCount >= group.getMaxMembers()) {
            throw new IllegalStateException("Play group is full");
        }

        PlayGroupMemberEntity existing = memberRepository.findByGroupIdAndUserId(groupId, target.id()).orElse(null);
        if (existing != null) {
            if (existing.getStatus() == PlayGroupMemberStatus.ACTIVE) {
                throw new IllegalStateException("User is already a member");
            }
            existing.setStatus(PlayGroupMemberStatus.ACTIVE);
            existing.setRole(PlayGroupMemberRole.MEMBER);
            existing.setAddedById(actorId);
            existing.setLeftAt(null);
            memberRepository.save(existing);
        } else {
            memberRepository.save(PlayGroupMemberEntity.builder()
                    .groupId(groupId)
                    .userId(target.id())
                    .role(PlayGroupMemberRole.MEMBER)
                    .status(PlayGroupMemberStatus.ACTIVE)
                    .addedById(actorId)
                    .build());
        }

        return toResponse(group, true);
    }

    @Transactional
    public PlayGroupResponse removeMember(long actorId, long groupId, long targetUserId) {
        PlayGroupEntity group = requireActiveGroup(groupId);
        PlayGroupMemberEntity membership = memberRepository.findByGroupIdAndUserId(groupId, targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Member not found"));
        if (membership.getStatus() != PlayGroupMemberStatus.ACTIVE) {
            throw new IllegalStateException("Member is not active");
        }
        if (membership.getRole() == PlayGroupMemberRole.OWNER) {
            throw new ForbiddenOperationException("Cannot remove the group owner");
        }

        boolean selfLeave = actorId == targetUserId;
        if (!selfLeave) {
            requireOwner(group, actorId);
        } else {
            requireActiveMember(groupId, actorId);
        }

        membership.setStatus(selfLeave ? PlayGroupMemberStatus.LEFT : PlayGroupMemberStatus.REMOVED);
        membership.setLeftAt(Instant.now());
        memberRepository.save(membership);
        return toResponse(group, true);
    }

    @Transactional
    public StartPlayGroupGameResponse startGame(
            long ownerId,
            long groupId,
            String roomName,
            Integer maxPlayers,
            BigDecimal stakeAmount,
            GameType gameType,
            GameVariant gameVariant,
            Integer dealsPerMatch
    ) {
        PlayGroupEntity group = requireActiveGroup(groupId);
        requireOwner(group, ownerId);

        UserSummary owner = userLookupPort.findById(ownerId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        List<PlayGroupMemberEntity> members =
                memberRepository.findByGroupIdAndStatus(groupId, PlayGroupMemberStatus.ACTIVE);
        List<Long> inviteeIds = members.stream()
                .map(PlayGroupMemberEntity::getUserId)
                .filter(id -> !id.equals(ownerId))
                .toList();

        String name = (roomName == null || roomName.isBlank())
                ? group.getName()
                : roomName.trim();

        RoomSummary room = roomPort.createWaitingRoom(
                owner.username(),
                new CreateWaitingRoomCommand(
                        name,
                        maxPlayers,
                        stakeAmount,
                        gameType != null ? gameType : GameType.RUMMY,
                        gameVariant != null ? gameVariant : GameVariant.POOL_101,
                        dealsPerMatch
                )
        );

        List<InvitationView> invites = invitationPort.createBatch(new CreateInvitationsCommand(
                room.id(),
                groupId,
                ownerId,
                inviteeIds,
                null
        ));

        List<InvitationResponse> responses = invites.stream().map(InvitationResponse::from).toList();
        return new StartPlayGroupGameResponse(room.id(), room.roomCode(), groupId, group.getName(), responses);
    }

    private PlayGroupEntity requireActiveGroup(long groupId) {
        PlayGroupEntity group = groupRepository.findById(groupId)
                .orElseThrow(() -> new ResourceNotFoundException("Play group not found"));
        if (group.getStatus() != PlayGroupStatus.ACTIVE) {
            throw new ResourceNotFoundException("Play group not found");
        }
        return group;
    }

    private void requireOwner(PlayGroupEntity group, long userId) {
        if (!group.getOwnerId().equals(userId)) {
            throw new ForbiddenOperationException("Only the group owner can perform this action");
        }
    }

    private void requireActiveMember(long groupId, long userId) {
        if (!memberRepository.existsByGroupIdAndUserIdAndStatus(groupId, userId, PlayGroupMemberStatus.ACTIVE)) {
            throw new ForbiddenOperationException("Not a member of this play group");
        }
    }

    private UserSummary resolveUser(Long userId, String username) {
        if (userId != null) {
            return userLookupPort.findById(userId)
                    .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        }
        return userLookupPort.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
    }

    private String requireName(String name) {
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("Group name is required");
        }
        String trimmed = name.trim();
        if (trimmed.length() > 64) {
            throw new IllegalArgumentException("Group name must be at most 64 characters");
        }
        return trimmed;
    }

    private PlayGroupResponse toResponse(PlayGroupEntity group, boolean includeMembers) {
        UserSummary owner = userLookupPort.findById(group.getOwnerId()).orElse(null);
        List<PlayGroupMemberResponse> members = List.of();
        int memberCount = (int) memberRepository.countByGroupIdAndStatus(group.getId(), PlayGroupMemberStatus.ACTIVE);
        if (includeMembers) {
            List<PlayGroupMemberEntity> rows =
                    memberRepository.findByGroupIdAndStatus(group.getId(), PlayGroupMemberStatus.ACTIVE);
            List<Long> ids = rows.stream().map(PlayGroupMemberEntity::getUserId).toList();
            Map<Long, UserSummary> users = userLookupPort.findByIds(ids);
            List<PlayGroupMemberResponse> out = new ArrayList<>();
            for (PlayGroupMemberEntity row : rows) {
                UserSummary summary = users.get(row.getUserId());
                if (summary == null) {
                    continue;
                }
                out.add(new PlayGroupMemberResponse(
                        summary.id(),
                        summary.username(),
                        summary.displayName(),
                        row.getRole(),
                        row.getStatus(),
                        row.getJoinedAt()
                ));
            }
            members = out;
            memberCount = out.size();
        }
        return new PlayGroupResponse(
                group.getId(),
                group.getName(),
                group.getOwnerId(),
                owner != null ? owner.username() : null,
                group.getStatus(),
                group.getType(),
                group.getMaxMembers(),
                memberCount,
                group.getCreatedAt(),
                group.getUpdatedAt(),
                members
        );
    }
}
