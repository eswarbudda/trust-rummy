package com.trustrummy.backend.recentplayers;

import com.trustrummy.backend.friends.FriendPort;
import com.trustrummy.backend.friends.FriendsCommandPort;
import com.trustrummy.backend.friends.FriendshipView;
import com.trustrummy.backend.presence.PresenceService;
import com.trustrummy.backend.users.UserLookupPort;
import com.trustrummy.backend.users.UserSummary;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class RecentPlayersService implements RecentPlayersPort {

    private static final int DEFAULT_LIMIT = 30;
    private static final int MAX_LIMIT = 50;

    private final RecentPlayerEncounterRepository encounterRepository;
    private final UserLookupPort userLookupPort;
    private final PresenceService presenceService;
    private final FriendPort friendPort;
    private final FriendsCommandPort friendsCommandPort;

    @Override
    @Transactional
    public void recordEncounters(Collection<Long> participantUserIds, Long roomId, String roomCode, Instant playedAt) {
        if (participantUserIds == null || participantUserIds.size() < 2) {
            return;
        }
        Instant at = playedAt != null ? playedAt : Instant.now();
        List<Long> ids = participantUserIds.stream().distinct().toList();
        for (Long userId : ids) {
            for (Long opponentId : ids) {
                if (userId.equals(opponentId)) {
                    continue;
                }
                encounterRepository.upsertEncounter(userId, opponentId, roomId, roomCode, at);
            }
        }
    }

    @Transactional(readOnly = true)
    public List<RecentOpponentResponse> listRecent(long userId, int limit) {
        int safeLimit = Math.min(Math.max(limit, 1), MAX_LIMIT);
        List<RecentPlayerEncounterEntity> rows =
                encounterRepository.findByUserIdOrderByLastPlayedAtDesc(userId, PageRequest.of(0, safeLimit));
        List<Long> opponentIds = rows.stream().map(RecentPlayerEncounterEntity::getOpponentId).toList();
        Map<Long, UserSummary> users = userLookupPort.findByIds(opponentIds);
        Set<Long> online = presenceService.filterOnline(opponentIds);

        List<RecentOpponentResponse> out = new ArrayList<>();
        for (RecentPlayerEncounterEntity row : rows) {
            UserSummary summary = users.get(row.getOpponentId());
            if (summary == null) {
                continue;
            }
            out.add(new RecentOpponentResponse(
                    summary.id(),
                    summary.username(),
                    summary.displayName(),
                    online.contains(summary.id()),
                    friendPort.areFriends(userId, summary.id()),
                    row.getMatchCount(),
                    row.getLastPlayedAt(),
                    row.getLastRoomCode()
            ));
        }
        return out;
    }

    @Transactional
    public FriendshipView sendFriendRequest(long requesterId, long opponentUserId) {
        return friendsCommandPort.sendRequestByUserId(requesterId, opponentUserId);
    }

    public List<RecentOpponentResponse> listRecent(long userId) {
        return listRecent(userId, DEFAULT_LIMIT);
    }
}
