package com.trustrummy.backend.invitations;

import com.trustrummy.backend.exception.ForbiddenOperationException;
import com.trustrummy.backend.exception.ResourceNotFoundException;
import com.trustrummy.backend.friends.FriendPort;
import com.trustrummy.backend.notifications.NotificationPort;
import com.trustrummy.backend.notifications.NotificationTypes;
import com.trustrummy.backend.rooms.RoomPort;
import com.trustrummy.backend.rooms.RoomSummary;
import com.trustrummy.backend.users.UserLookupPort;
import com.trustrummy.backend.users.UserSummary;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class InvitationsService implements InvitationPort {

    static final Duration DEFAULT_TTL = Duration.ofMinutes(30);

    private final GameInvitationRepository invitationRepository;
    private final RoomPort roomPort;
    private final UserLookupPort userLookupPort;
    private final NotificationPort notificationPort;
    private final FriendPort friendPort;

    @Override
    @Transactional
    public List<InvitationView> createBatch(CreateInvitationsCommand command) {
        if (command.inviteeIds() == null || command.inviteeIds().isEmpty()) {
            return List.of();
        }
        RoomSummary room = roomPort.requireById(command.roomId());
        if (!room.isWaiting()) {
            throw new IllegalStateException("Room is no longer accepting invitations");
        }
        Instant expiresAt = command.expiresAt() != null
                ? command.expiresAt()
                : Instant.now().plus(DEFAULT_TTL);

        UserSummary inviter = userLookupPort.findById(command.inviterId())
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        List<InvitationView> created = new ArrayList<>();
        for (Long inviteeId : command.inviteeIds()) {
            if (inviteeId == null || inviteeId.equals(command.inviterId())) {
                continue;
            }
            created.add(upsertPending(
                    room,
                    command.groupId(),
                    inviter,
                    inviteeId,
                    expiresAt
            ));
        }
        return created;
    }

    @Transactional
    public List<InvitationResponse> listPendingForUser(long userId) {
        List<GameInvitationEntity> rows =
                invitationRepository.findByInviteeIdAndStatusOrderByCreatedAtDesc(userId, InvitationStatus.PENDING);
        List<InvitationResponse> out = new ArrayList<>();
        for (GameInvitationEntity row : rows) {
            InvitationView view = refreshIfNeeded(row);
            if (view.status() == InvitationStatus.PENDING) {
                out.add(InvitationResponse.from(view));
            }
        }
        return out;
    }

    @Transactional
    public InvitationResponse accept(long userId, UUID invitationId) {
        GameInvitationEntity invite = requireInviteePending(userId, invitationId);
        InvitationView refreshed = refreshIfNeeded(invite);
        if (refreshed.status() != InvitationStatus.PENDING) {
            throw new IllegalStateException("Invitation is no longer pending");
        }

        RoomSummary room = roomPort.requireById(invite.getRoomId());
        if (!room.isWaiting()) {
            invite.setStatus(InvitationStatus.CANCELLED);
            invite.setRespondedAt(Instant.now());
            invitationRepository.save(invite);
            throw new IllegalStateException("Room is no longer accepting players");
        }

        UserSummary invitee = userLookupPort.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        // Seat only after invitation validation — never create RoomPlayer earlier.
        roomPort.joinRoom(invitee.username(), room.roomCode());

        invite.setStatus(InvitationStatus.ACCEPTED);
        invite.setRespondedAt(Instant.now());
        GameInvitationEntity saved = invitationRepository.save(invite);

        notificationPort.create(
                invite.getInviterId(),
                NotificationTypes.ROOM_INVITATION,
                Map.of(
                        "event", "ACCEPTED",
                        "invitationId", saved.getId().toString(),
                        "roomCode", room.roomCode(),
                        "username", invitee.username()
                ),
                "invite-accepted:" + saved.getId()
        );

        return InvitationResponse.from(toView(saved, room));
    }

    @Transactional
    public InvitationResponse decline(long userId, UUID invitationId) {
        GameInvitationEntity invite = requireInviteePending(userId, invitationId);
        InvitationView refreshed = refreshIfNeeded(invite);
        if (refreshed.status() != InvitationStatus.PENDING) {
            throw new IllegalStateException("Invitation is no longer pending");
        }
        invite.setStatus(InvitationStatus.DECLINED);
        invite.setRespondedAt(Instant.now());
        GameInvitationEntity saved = invitationRepository.save(invite);
        RoomSummary room = roomPort.requireById(saved.getRoomId());
        return InvitationResponse.from(toView(saved, room));
    }

    @Transactional
    public Map<String, List<InvitationResponse>> listForRoom(long actorId, String roomCode) {
        RoomSummary room = roomPort.requireByCode(roomCode);
        requireHost(actorId, room);

        List<GameInvitationEntity> rows = invitationRepository.findByRoomIdOrderByCreatedAtDesc(room.id());
        Map<String, List<InvitationResponse>> body = new LinkedHashMap<>();
        body.put("pending", new ArrayList<>());
        body.put("accepted", new ArrayList<>());
        body.put("declined", new ArrayList<>());
        body.put("expired", new ArrayList<>());
        body.put("cancelled", new ArrayList<>());

        for (GameInvitationEntity row : rows) {
            InvitationView view = refreshIfNeeded(row);
            InvitationResponse response = InvitationResponse.from(view);
            switch (view.status()) {
                case PENDING -> body.get("pending").add(response);
                case ACCEPTED -> body.get("accepted").add(response);
                case DECLINED -> body.get("declined").add(response);
                case EXPIRED -> body.get("expired").add(response);
                case CANCELLED -> body.get("cancelled").add(response);
            }
        }
        return body;
    }

    @Transactional
    public InvitationResponse inviteToRoom(long inviterId, String roomCode, long inviteeId) {
        RoomSummary room = roomPort.requireByCode(roomCode);
        requireHost(inviterId, room);
        if (!room.isWaiting()) {
            throw new IllegalStateException("Room is no longer accepting invitations");
        }
        if (inviteeId == inviterId) {
            throw new IllegalArgumentException("Cannot invite yourself");
        }
        if (!friendPort.areFriends(inviterId, inviteeId)) {
            throw new ForbiddenOperationException("Can only invite accepted friends");
        }

        UserSummary inviter = userLookupPort.findById(inviterId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        Instant expiresAt = Instant.now().plus(DEFAULT_TTL);
        return InvitationResponse.from(upsertPending(room, null, inviter, inviteeId, expiresAt));
    }

    private InvitationView upsertPending(
            RoomSummary room,
            Long groupId,
            UserSummary inviter,
            long inviteeId,
            Instant expiresAt
    ) {
        UserSummary invitee = userLookupPort.findById(inviteeId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        GameInvitationEntity existing =
                invitationRepository.findByRoomIdAndInviteeId(room.id(), inviteeId).orElse(null);
        GameInvitationEntity saved;
        if (existing == null) {
            saved = invitationRepository.save(GameInvitationEntity.builder()
                    .roomId(room.id())
                    .groupId(groupId)
                    .inviterId(inviter.id())
                    .inviteeId(inviteeId)
                    .status(InvitationStatus.PENDING)
                    .channel(InvitationChannel.IN_APP)
                    .expiresAt(expiresAt)
                    .build());
        } else {
            switch (existing.getStatus()) {
                case PENDING -> {
                    // Idempotent re-send: refresh expiry + notify again.
                    existing.setExpiresAt(expiresAt);
                    if (groupId != null) {
                        existing.setGroupId(groupId);
                    }
                    saved = invitationRepository.save(existing);
                }
                case ACCEPTED -> throw new IllegalStateException("User already accepted this room invite");
                case DECLINED, EXPIRED, CANCELLED -> {
                    existing.setStatus(InvitationStatus.PENDING);
                    existing.setInviterId(inviter.id());
                    existing.setGroupId(groupId);
                    existing.setExpiresAt(expiresAt);
                    existing.setRespondedAt(null);
                    saved = invitationRepository.save(existing);
                }
                default -> throw new IllegalStateException("Invalid invitation state");
            }
        }

        notifyInvitee(saved, room, inviter, invitee);
        return toView(saved, room, inviter, invitee);
    }

    private void notifyInvitee(
            GameInvitationEntity invite,
            RoomSummary room,
            UserSummary inviter,
            UserSummary invitee
    ) {
        Map<String, Object> payload = new HashMap<>();
        payload.put("invitationId", invite.getId().toString());
        payload.put("roomId", room.id());
        payload.put("roomCode", room.roomCode());
        payload.put("inviterId", inviter.id());
        payload.put("inviterUsername", inviter.username());
        if (invite.getGroupId() != null) {
            payload.put("groupId", invite.getGroupId());
        }

        String type = invite.getGroupId() != null
                ? NotificationTypes.GROUP_INVITATION
                : NotificationTypes.ROOM_INVITATION;

        notificationPort.create(
                invitee.id(),
                type,
                payload,
                "room-invite:" + invite.getId() + ":" + invite.getExpiresAt().toEpochMilli()
        );
    }

    private GameInvitationEntity requireInviteePending(long userId, UUID invitationId) {
        GameInvitationEntity invite = invitationRepository.findById(invitationId)
                .orElseThrow(() -> new ResourceNotFoundException("Invitation not found"));
        if (!invite.getInviteeId().equals(userId)) {
            throw new ForbiddenOperationException("Not your invitation");
        }
        return invite;
    }

    private void requireHost(long actorId, RoomSummary room) {
        if (room.createdByUserId() != actorId) {
            throw new ForbiddenOperationException("Only the room host can manage invitations");
        }
    }

    private InvitationView refreshIfNeeded(GameInvitationEntity invite) {
        RoomSummary room = roomPort.requireById(invite.getRoomId());
        if (invite.getStatus() == InvitationStatus.PENDING) {
            if (invite.getExpiresAt().isBefore(Instant.now())) {
                invite.setStatus(InvitationStatus.EXPIRED);
                invite.setRespondedAt(Instant.now());
                invitationRepository.save(invite);
            } else if (!room.isWaiting()) {
                invite.setStatus(InvitationStatus.CANCELLED);
                invite.setRespondedAt(Instant.now());
                invitationRepository.save(invite);
            }
        }
        return toView(invite, room);
    }

    private InvitationView toView(GameInvitationEntity invite, RoomSummary room) {
        UserSummary inviter = userLookupPort.findById(invite.getInviterId()).orElse(null);
        UserSummary invitee = userLookupPort.findById(invite.getInviteeId()).orElse(null);
        return toView(invite, room, inviter, invitee);
    }

    private InvitationView toView(
            GameInvitationEntity invite,
            RoomSummary room,
            UserSummary inviter,
            UserSummary invitee
    ) {
        return new InvitationView(
                invite.getId(),
                invite.getRoomId(),
                room.roomCode(),
                invite.getGroupId(),
                invite.getInviterId(),
                inviter != null ? inviter.username() : null,
                invite.getInviteeId(),
                invitee != null ? invitee.username() : null,
                invitee != null ? invitee.displayName() : null,
                invite.getStatus(),
                invite.getExpiresAt(),
                invite.getCreatedAt(),
                invite.getRespondedAt()
        );
    }
}
