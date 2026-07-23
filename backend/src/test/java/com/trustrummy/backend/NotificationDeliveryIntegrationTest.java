package com.trustrummy.backend;

import com.trustrummy.backend.notifications.NotificationPort;
import com.trustrummy.backend.notifications.NotificationTypes;
import com.trustrummy.backend.notifications.NotificationView;
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

class NotificationDeliveryIntegrationTest extends AbstractGameIntegrationTest {

    @Autowired
    private NotificationPort notificationPort;

    @Test
    void persistsAndDeliversOverUserSocketWhenOnline() throws Exception {
        long unique = System.nanoTime();
        Map<String, Object> auth = register("notif_" + unique);
        String token = (String) auth.get("token");

        ResponseEntity<Map> me = rest.exchange(
                baseUrl("/api/v1/presence/me"),
                HttpMethod.GET,
                new HttpEntity<>(authHeaders(token)),
                Map.class
        );
        long userId = ((Number) me.getBody().get("userId")).longValue();

        TestWsClient socket = connectUser(token);
        try {
            assertEvent(socket, "PRESENCE");

            NotificationView created = notificationPort.create(
                    userId,
                    NotificationTypes.FRIEND_REQUEST,
                    Map.of("fromUsername", "bob", "friendshipId", 42),
                    "friend-req:test:" + unique
            );

            Map<String, Object> frame = assertEvent(socket, "NOTIFICATION");
            assertThat(frame.get("notificationId")).isEqualTo(created.id().toString());
            assertThat(frame.get("notificationType")).isEqualTo(NotificationTypes.FRIEND_REQUEST);
            assertEvent(socket, "NOTIFICATION_COUNT");

            ResponseEntity<Map> inbox = rest.exchange(
                    baseUrl("/api/v1/notifications?status=UNREAD"),
                    HttpMethod.GET,
                    new HttpEntity<>(authHeaders(token)),
                    Map.class
            );
            assertThat(inbox.getStatusCode()).isEqualTo(HttpStatus.OK);
            assertThat(((Number) inbox.getBody().get("unreadCount")).intValue()).isGreaterThanOrEqualTo(1);
            @SuppressWarnings("unchecked")
            List<Map<String, Object>> items = (List<Map<String, Object>>) inbox.getBody().get("items");
            assertThat(items).isNotEmpty();

            ResponseEntity<Map> read = rest.exchange(
                    baseUrl("/api/v1/notifications/" + created.id() + "/read"),
                    HttpMethod.POST,
                    new HttpEntity<>(authHeaders(token)),
                    Map.class
            );
            assertThat(read.getStatusCode()).isEqualTo(HttpStatus.OK);
            assertThat(read.getBody().get("status")).isEqualTo("READ");
        } finally {
            socket.close();
        }
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
