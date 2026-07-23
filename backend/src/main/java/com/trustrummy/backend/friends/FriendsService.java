package com.trustrummy.backend.friends;

import com.trustrummy.backend.exception.ForbiddenOperationException;
import com.trustrummy.backend.exception.ResourceNotFoundException;
import com.trustrummy.backend.notifications.NotificationPort;
import com.trustrummy.backend.notifications.NotificationTypes;
import com.trustrummy.backend.presence.PresenceService;
import com.trustrummy.backend.users.UserLookupPort;
import com.trustrummy.backend.users.UserSummary;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class FriendsService implements FriendPort, FriendsCommandPort {

    private final FriendshipRepository friendshipRepository;
    private final UserLookupPort userLookupPort;
    private final NotificationPort notificationPort;
    private final PresenceService presenceService;

    @Override
    @Transactional(readOnly = true)
    public boolean areFriends(long userId, long otherUserId) {
        if (userId == otherUserId) {
            return false;
        }
        return friendshipRepository.areFriends(userId, otherUserId);
    }

    @Transactional(readOnly = true)
    public List<FriendResponse> listFriends(long userId) {
        List<FriendshipEntity> rows = friendshipRepository.findByUserAndStatus(userId, FriendshipStatus.ACCEPTED);
        List<Long> otherIds = rows.stream().map(f -> f.otherUserId(userId)).toList();
        Map<Long, UserSummary> users = userLookupPort.findByIds(otherIds);
        Set<Long> online = presenceService.filterOnline(otherIds);

        List<FriendResponse> out = new ArrayList<>();
        for (FriendshipEntity f : rows) {
            long otherId = f.otherUserId(userId);
            UserSummary summary = users.get(otherId);
            if (summary == null) {
                continue;
            }
            Instant since = f.getRespondedAt() != null ? f.getRespondedAt() : f.getCreatedAt();
            out.add(new FriendResponse(
                    f.getId(),
                    summary.id(),
                    summary.username(),
                    summary.displayName(),
                    online.contains(otherId),
                    since
            ));
        }
        return out;
    }

    @Transactional(readOnly = true)
    public Map<String, List<FriendRequestResponse>> listRequests(long userId) {
        List<FriendshipEntity> pending = friendshipRepository.findByUserAndStatus(userId, FriendshipStatus.PENDING);
        List<Long> otherIds = pending.stream().map(f -> f.otherUserId(userId)).toList();
        Map<Long, UserSummary> users = userLookupPort.findByIds(otherIds);

        List<FriendRequestResponse> incoming = new ArrayList<>();
        List<FriendRequestResponse> outgoing = new ArrayList<>();
        for (FriendshipEntity f : pending) {
            long otherId = f.otherUserId(userId);
            UserSummary summary = users.get(otherId);
            if (summary == null) {
                continue;
            }
            FriendRequestResponse item = new FriendRequestResponse(
                    f.getId(),
                    f.getAddresseeId().equals(userId) ? "INCOMING" : "OUTGOING",
                    summary.id(),
                    summary.username(),
                    summary.displayName(),
                    f.getCreatedAt()
            );
            if (f.getAddresseeId().equals(userId)) {
                incoming.add(item);
            } else {
                outgoing.add(item);
            }
        }
        Map<String, List<FriendRequestResponse>> body = new LinkedHashMap<>();
        body.put("incoming", incoming);
        body.put("outgoing", outgoing);
        return body;
    }

    @Override
    @Transactional
    public FriendshipView sendRequestByUsername(long requesterId, String username) {
        UserSummary target = userLookupPort.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        return sendRequestByUserId(requesterId, target.id());
    }

    @Override
    @Transactional
    public FriendshipView sendRequestByUserId(long requesterId, long addresseeId) {
        if (requesterId == addresseeId) {
            throw new IllegalArgumentException("Cannot friend yourself");
        }
        UserSummary addressee = userLookupPort.findById(addresseeId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        UserSummary requester = userLookupPort.findById(requesterId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        FriendshipEntity existing = friendshipRepository.findPair(requesterId, addresseeId).orElse(null);
        FriendshipEntity saved;
        if (existing == null) {
            FriendshipEntity created = FriendshipEntity.builder()
                    .requesterId(requesterId)
                    .addresseeId(addresseeId)
                    .status(FriendshipStatus.PENDING)
                    .build();
            saved = friendshipRepository.save(created);
        } else {
            switch (existing.getStatus()) {
                case PENDING -> throw new IllegalStateException("Friend request already pending");
                case ACCEPTED -> throw new IllegalStateException("Already friends");
                case BLOCKED -> throw new ForbiddenOperationException("Cannot send friend request");
                case DECLINED, REMOVED -> {
                    existing.setRequesterId(requesterId);
                    existing.setAddresseeId(addresseeId);
                    existing.setStatus(FriendshipStatus.PENDING);
                    existing.setRespondedAt(null);
                    saved = friendshipRepository.save(existing);
                }
                default -> throw new IllegalStateException("Invalid friendship state");
            }
        }

        notifyFriendRequest(requester, addressee, saved);
        return FriendshipView.from(saved);
    }

    @Transactional
    public FriendshipView accept(long userId, long friendshipId) {
        FriendshipEntity friendship = requireOwnedPending(userId, friendshipId, true);
        friendship.setStatus(FriendshipStatus.ACCEPTED);
        friendship.setRespondedAt(Instant.now());
        FriendshipEntity saved = friendshipRepository.save(friendship);

        UserSummary accepter = userLookupPort.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        notificationPort.create(
                saved.getRequesterId(),
                NotificationTypes.FRIEND_ACCEPTED,
                Map.of(
                        "friendshipId", saved.getId(),
                        "username", accepter.username()
                ),
                "friend-accepted:" + saved.getId()
        );
        return FriendshipView.from(saved);
    }

    @Transactional
    public FriendshipView decline(long userId, long friendshipId) {
        FriendshipEntity friendship = requireOwnedPending(userId, friendshipId, true);
        friendship.setStatus(FriendshipStatus.DECLINED);
        friendship.setRespondedAt(Instant.now());
        return FriendshipView.from(friendshipRepository.save(friendship));
    }

    @Transactional
    public FriendshipView unfriend(long userId, long otherUserId) {
        FriendshipEntity friendship = friendshipRepository.findPair(userId, otherUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Friendship not found"));
        if (friendship.getStatus() != FriendshipStatus.ACCEPTED) {
            throw new IllegalStateException("Not currently friends");
        }
        friendship.setStatus(FriendshipStatus.REMOVED);
        friendship.setRespondedAt(Instant.now());
        return FriendshipView.from(friendshipRepository.save(friendship));
    }

    @Transactional
    public FriendshipView block(long userId, long otherUserId) {
        if (userId == otherUserId) {
            throw new IllegalArgumentException("Cannot block yourself");
        }
        userLookupPort.findById(otherUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        FriendshipEntity existing = friendshipRepository.findPair(userId, otherUserId).orElse(null);
        FriendshipEntity saved;
        if (existing == null) {
            saved = friendshipRepository.save(FriendshipEntity.builder()
                    .requesterId(userId)
                    .addresseeId(otherUserId)
                    .status(FriendshipStatus.BLOCKED)
                    .respondedAt(Instant.now())
                    .build());
        } else {
            existing.setStatus(FriendshipStatus.BLOCKED);
            existing.setRespondedAt(Instant.now());
            saved = friendshipRepository.save(existing);
        }
        return FriendshipView.from(saved);
    }

    private FriendshipEntity requireOwnedPending(long userId, long friendshipId, boolean addresseeOnly) {
        FriendshipEntity friendship = friendshipRepository.findById(friendshipId)
                .orElseThrow(() -> new ResourceNotFoundException("Friend request not found"));
        if (friendship.getStatus() != FriendshipStatus.PENDING) {
            throw new IllegalStateException("Friend request is not pending");
        }
        if (addresseeOnly && !friendship.getAddresseeId().equals(userId)) {
            throw new ForbiddenOperationException("Only the addressee can respond");
        }
        if (!friendship.getRequesterId().equals(userId) && !friendship.getAddresseeId().equals(userId)) {
            throw new ForbiddenOperationException("Not a participant");
        }
        return friendship;
    }

    private void notifyFriendRequest(UserSummary requester, UserSummary addressee, FriendshipEntity friendship) {
        notificationPort.create(
                addressee.id(),
                NotificationTypes.FRIEND_REQUEST,
                Map.of(
                        "friendshipId", friendship.getId(),
                        "fromUserId", requester.id(),
                        "fromUsername", requester.username()
                ),
                "friend-req:" + friendship.getId() + ":" + Instant.now().toEpochMilli()
        );
    }
}
