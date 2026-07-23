package com.trustrummy.backend;

import com.trustrummy.backend.presence.PresenceService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.net.URI;
import java.net.http.WebSocket;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;

class PresenceWebSocketIntegrationTest extends AbstractGameIntegrationTest {

    @Autowired
    private PresenceService presenceService;

    @Test
    void userSocketMarksOnlineAndOffAgain() throws Exception {
        long unique = System.nanoTime();
        Map<String, Object> auth = register("pres_" + unique);
        String token = (String) auth.get("token");

        ResponseEntity<Map> before = rest.exchange(
                baseUrl("/api/v1/presence/me"),
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(token)),
                Map.class
        );
        assertThat(before.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(before.getBody().get("status")).isEqualTo("OFFLINE");

        TestWsClient socket = connectUser(token);
        try {
            Map<String, Object> presenceEvent = assertEvent(socket, "PRESENCE");
            assertThat(presenceEvent.get("status")).isEqualTo("ONLINE");

            long userId = ((Number) before.getBody().get("userId")).longValue();
            assertThat(presenceService.isOnline(userId)).isTrue();

            ResponseEntity<Map> during = rest.exchange(
                    baseUrl("/api/v1/presence/me"),
                    HttpMethod.GET,
                    new HttpEntity<>(authHeaders(token)),
                    Map.class
            );
            assertThat(during.getBody().get("status")).isEqualTo("ONLINE");
            assertThat(((Number) during.getBody().get("sessionCount")).intValue()).isGreaterThanOrEqualTo(1);

            socket.send(Map.of("type", "HEARTBEAT"));
            Map<String, Object> ack = assertEvent(socket, "HEARTBEAT_ACK");
            assertThat(ack.get("status")).isEqualTo("ONLINE");

            ResponseEntity<Map> batch = rest.exchange(
                    baseUrl("/api/v1/presence?userIds=" + userId),
                    HttpMethod.GET,
                    new HttpEntity<>(authHeaders(token)),
                    Map.class
            );
            assertThat(batch.getStatusCode()).isEqualTo(HttpStatus.OK);
            @SuppressWarnings("unchecked")
            List<Map<String, Object>> results = (List<Map<String, Object>>) batch.getBody().get("results");
            assertThat(results).hasSize(1);
            assertThat(results.get(0).get("status")).isEqualTo("ONLINE");
        } finally {
            socket.close();
        }

        // Allow close callback to unregister.
        Thread.sleep(300);
        long userId = ((Number) before.getBody().get("userId")).longValue();
        assertThat(presenceService.isOnline(userId)).isFalse();
    }

    private TestWsClient connectUser(String jwt) throws Exception {
        TestWsClient client = new TestWsClient(objectMapper);
        URI uri = URI.create("ws://localhost:" + port + "/ws/user?token=" + jwt);
        WebSocket socket = httpClient.newWebSocketBuilder()
                .buildAsync(uri, client)
                .get(5, TimeUnit.SECONDS);
        client.attach(socket);
        return client;
    }
}
