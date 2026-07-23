package com.trustrummy.backend.presence;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

class InMemoryPresenceServiceTest {

    private InMemoryPresenceService presence;

    @BeforeEach
    void setUp() {
        presence = new InMemoryPresenceService();
    }

    @Test
    void userIsOfflineUntilConnect() {
        assertThat(presence.isOnline(1L)).isFalse();
        assertThat(presence.getStatus(1L)).isEqualTo(PresenceStatus.OFFLINE);
        assertThat(presence.sessionCount(1L)).isZero();
    }

    @Test
    void connectMakesUserOnline() {
        presence.onConnect(1L, "s1");
        assertThat(presence.isOnline(1L)).isTrue();
        assertThat(presence.getStatus(1L)).isEqualTo(PresenceStatus.ONLINE);
        assertThat(presence.sessionCount(1L)).isEqualTo(1);
    }

    @Test
    void multiDeviceStaysOnlineUntilLastSessionCloses() {
        presence.onConnect(1L, "s1");
        presence.onConnect(1L, "s2");
        assertThat(presence.sessionCount(1L)).isEqualTo(2);

        presence.onDisconnect(1L, "s1");
        assertThat(presence.isOnline(1L)).isTrue();
        assertThat(presence.sessionCount(1L)).isEqualTo(1);

        presence.onDisconnect(1L, "s2");
        assertThat(presence.isOnline(1L)).isFalse();
        assertThat(presence.sessionCount(1L)).isZero();
    }

    @Test
    void filterOnlineReturnsOnlyConnectedUsers() {
        presence.onConnect(10L, "a");
        presence.onConnect(30L, "c");

        Set<Long> online = presence.filterOnline(List.of(10L, 20L, 30L, 40L));
        assertThat(online).containsExactlyInAnyOrder(10L, 30L);
    }

    @Test
    void heartbeatRebindsMissingSession() {
        presence.heartbeat(5L, "ghost");
        assertThat(presence.isOnline(5L)).isTrue();
        assertThat(presence.sessionCount(5L)).isEqualTo(1);
    }
}
