package com.trustrummy.backend.recentplayers;

import com.trustrummy.backend.friends.FriendPort;
import com.trustrummy.backend.friends.FriendsCommandPort;
import com.trustrummy.backend.friends.FriendshipStatus;
import com.trustrummy.backend.friends.FriendshipView;
import com.trustrummy.backend.presence.PresenceService;
import com.trustrummy.backend.users.UserLookupPort;
import com.trustrummy.backend.users.UserSummary;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RecentPlayersServiceTest {

    @Mock
    private RecentPlayerEncounterRepository encounterRepository;
    @Mock
    private UserLookupPort userLookupPort;
    @Mock
    private PresenceService presenceService;
    @Mock
    private FriendPort friendPort;
    @Mock
    private FriendsCommandPort friendsCommandPort;

    private RecentPlayersService service;

    @BeforeEach
    void setUp() {
        service = new RecentPlayersService(
                encounterRepository, userLookupPort, presenceService, friendPort, friendsCommandPort);
    }

    @Test
    void recordEncountersWritesDirectedPairs() {
        Instant at = Instant.parse("2026-07-23T12:00:00Z");
        service.recordEncounters(List.of(1L, 2L, 3L), 9L, "ABC123", at);

        verify(encounterRepository, times(6)).upsertEncounter(anyLong(), anyLong(), eq(9L), eq("ABC123"), eq(at));
        verify(encounterRepository).upsertEncounter(1L, 2L, 9L, "ABC123", at);
        verify(encounterRepository).upsertEncounter(1L, 3L, 9L, "ABC123", at);
        verify(encounterRepository).upsertEncounter(2L, 1L, 9L, "ABC123", at);
        verify(encounterRepository, never()).upsertEncounter(eq(1L), eq(1L), any(), any(), any());
    }

    @Test
    void recordEncountersNoopsForSinglePlayer() {
        service.recordEncounters(List.of(1L), 9L, "ABC123", Instant.now());
        verify(encounterRepository, never()).upsertEncounter(anyLong(), anyLong(), any(), any(), any());
    }

    @Test
    void listRecentEnrichesPresenceAndFriendship() {
        RecentPlayerEncounterEntity row = RecentPlayerEncounterEntity.builder()
                .id(1L)
                .userId(1L)
                .opponentId(2L)
                .lastRoomCode("ABC123")
                .lastPlayedAt(Instant.parse("2026-07-23T12:00:00Z"))
                .matchCount(4)
                .build();
        when(encounterRepository.findByUserIdOrderByLastPlayedAtDesc(eq(1L), any(Pageable.class)))
                .thenReturn(List.of(row));
        when(userLookupPort.findByIds(List.of(2L)))
                .thenReturn(Map.of(2L, new UserSummary(2L, "bob", "Bob")));
        when(presenceService.filterOnline(List.of(2L))).thenReturn(Set.of(2L));
        when(friendPort.areFriends(1L, 2L)).thenReturn(true);

        List<RecentOpponentResponse> list = service.listRecent(1L, 10);

        assertThat(list).hasSize(1);
        assertThat(list.get(0).username()).isEqualTo("bob");
        assertThat(list.get(0).online()).isTrue();
        assertThat(list.get(0).alreadyFriends()).isTrue();
        assertThat(list.get(0).matchCount()).isEqualTo(4);
    }

    @Test
    void sendFriendRequestDelegatesToFriendsCommandPort() {
        FriendshipView view = new FriendshipView(
                10L, FriendshipStatus.PENDING, 1L, 2L, Instant.now(), null);
        when(friendsCommandPort.sendRequestByUserId(1L, 2L)).thenReturn(view);

        assertThat(service.sendFriendRequest(1L, 2L)).isEqualTo(view);
        verify(friendsCommandPort).sendRequestByUserId(1L, 2L);
    }
}
