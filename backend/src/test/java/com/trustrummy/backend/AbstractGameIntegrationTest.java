package com.trustrummy.backend;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.trustrummy.backend.dto.RegisterRequest;
import com.trustrummy.backend.dto.RoomCreateRequest;
import com.trustrummy.backend.dto.WalletAmountRequest;
import com.trustrummy.backend.game.model.GameVariant;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.WebSocket;
import java.util.List;
import java.util.Map;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.CompletionStage;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Shared REST + WebSocket plumbing for the full-stack gameplay integration
 * tests under this package (register/deposit/create-room/join-room over
 * REST, then a real {@code /ws/game/{roomCode}} client). Pulled out of
 * {@code GameWebSocketFlowIntegrationTest} once {@code StakeSettlementIntegrationTest}
 * needed the exact same setup.
 * <p>
 * Requires a real PostgreSQL instance reachable per
 * {@code application.properties} (e.g. {@code docker start rummy-postgres}
 * per the root README) — this project has no in-memory test datasource
 * configured, so these tests use the same database the app normally runs
 * against.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
abstract class AbstractGameIntegrationTest {

    @Value("${local.server.port}")
    protected int port;

    protected final TestRestTemplate rest = new TestRestTemplate();
    protected final ObjectMapper objectMapper = new ObjectMapper();
    protected final HttpClient httpClient = HttpClient.newHttpClient();

    protected Map<String, Object> register(String username) {
        RegisterRequest request = new RegisterRequest();
        request.setUsername(username);
        request.setEmail(username + "@example.com");
        request.setPassword("Password123!");
        request.setDisplayName(username);

        ResponseEntity<Map> response = rest.postForEntity(baseUrl("/api/v1/auth/register"), request, Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        @SuppressWarnings("unchecked")
        Map<String, Object> body = response.getBody();
        return body;
    }

    protected BigDecimal deposit(String jwt, BigDecimal amount) {
        WalletAmountRequest request = new WalletAmountRequest();
        request.setAmount(amount);
        HttpEntity<WalletAmountRequest> entity = new HttpEntity<>(request, authHeaders(jwt));
        ResponseEntity<Map> response = rest.exchange(baseUrl("/api/v1/wallet/deposit"), HttpMethod.POST, entity, Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        @SuppressWarnings("unchecked")
        Map<String, Object> body = response.getBody();
        return new BigDecimal(body.get("balance").toString());
    }

    protected BigDecimal getBalance(String jwt) {
        HttpEntity<Void> entity = new HttpEntity<>(authHeaders(jwt));
        ResponseEntity<Map> response = rest.exchange(baseUrl("/api/v1/wallet/balance"), HttpMethod.GET, entity, Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        @SuppressWarnings("unchecked")
        Map<String, Object> body = response.getBody();
        return new BigDecimal(body.get("balance").toString());
    }

    protected Map<String, Object> createRoom(String jwt, BigDecimal stakeAmount) {
        return createRoom(jwt, stakeAmount, null);
    }

    protected Map<String, Object> createRoom(String jwt, BigDecimal stakeAmount, String gameVariant) {
        RoomCreateRequest request = new RoomCreateRequest();
        request.setName("integration-test-room");
        request.setMaxPlayers(2);
        request.setStakeAmount(stakeAmount);
        if (gameVariant != null) {
            request.setGameVariant(GameVariant.valueOf(gameVariant));
        }

        HttpEntity<RoomCreateRequest> entity = new HttpEntity<>(request, authHeaders(jwt));
        ResponseEntity<Map> response = rest.exchange(baseUrl("/api/v1/rooms"), HttpMethod.POST, entity, Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        @SuppressWarnings("unchecked")
        Map<String, Object> body = response.getBody();
        return body;
    }

    protected Map<String, Object> joinRoom(String jwt, String roomCode) {
        HttpEntity<Void> entity = new HttpEntity<>(authHeaders(jwt));
        ResponseEntity<Map> response = rest.exchange(
                baseUrl("/api/v1/rooms/" + roomCode + "/join"), HttpMethod.POST, entity, Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        @SuppressWarnings("unchecked")
        Map<String, Object> body = response.getBody();
        return body;
    }

    protected HttpHeaders authHeaders(String jwt) {
        HttpHeaders headers = new HttpHeaders();
        headers.set(HttpHeaders.AUTHORIZATION, "Bearer " + jwt);
        return headers;
    }

    protected String baseUrl(String path) {
        return "http://localhost:" + port + path;
    }

    @SuppressWarnings("unchecked")
    protected long firstPlayerUserId(Map<String, Object> roomResponse) {
        List<Map<String, Object>> players = (List<Map<String, Object>>) roomResponse.get("players");
        return ((Number) players.get(0).get("userId")).longValue();
    }

    @SuppressWarnings("unchecked")
    protected long otherPlayerUserId(Map<String, Object> roomResponse, long excludingUserId) {
        List<Map<String, Object>> players = (List<Map<String, Object>>) roomResponse.get("players");
        return players.stream()
                .map(p -> ((Number) p.get("userId")).longValue())
                .filter(id -> id != excludingUserId)
                .findFirst()
                .orElseThrow(() -> new AssertionError("Expected a second seated player in " + roomResponse));
    }

    protected TestWsClient connect(String roomCode, String jwt) throws Exception {
        TestWsClient client = new TestWsClient(objectMapper);
        URI uri = URI.create("ws://localhost:" + port + "/ws/game/" + roomCode + "?token=" + jwt);
        WebSocket socket = httpClient.newWebSocketBuilder()
                .buildAsync(uri, client)
                .get(5, TimeUnit.SECONDS);
        client.attach(socket);
        return client;
    }

    protected Map<String, Object> assertEvent(TestWsClient client, String expectedType) throws InterruptedException {
        Map<String, Object> event = client.events.poll(5, TimeUnit.SECONDS);
        assertThat(event)
                .as("expected a %s event on socket within 5s but none arrived", expectedType)
                .isNotNull();
        assertThat(event.get("type"))
                .as("unexpected event type; full payload was: %s", event)
                .isEqualTo(expectedType);
        return event;
    }

    /** Minimal WebSocket client: queues every parsed JSON frame, in arrival order, for the test to assert against. */
    protected static final class TestWsClient implements WebSocket.Listener {
        final BlockingQueue<Map<String, Object>> events = new LinkedBlockingQueue<>();
        private final ObjectMapper mapper;
        private final StringBuilder buffer = new StringBuilder();
        private WebSocket socket;

        TestWsClient(ObjectMapper mapper) {
            this.mapper = mapper;
        }

        void attach(WebSocket socket) {
            this.socket = socket;
        }

        void send(Map<String, Object> action) {
            sendRaw(toJson(action));
        }

        void sendRaw(String rawText) {
            socket.sendText(rawText, true);
        }

        void close() {
            socket.sendClose(WebSocket.NORMAL_CLOSURE, "test done");
        }

        private String toJson(Map<String, Object> action) {
            try {
                return mapper.writeValueAsString(action);
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        }

        @Override
        public CompletionStage<?> onText(WebSocket webSocket, CharSequence data, boolean last) {
            buffer.append(data);
            if (last) {
                String message = buffer.toString();
                buffer.setLength(0);
                try {
                    @SuppressWarnings("unchecked")
                    Map<String, Object> parsed = mapper.readValue(message, Map.class);
                    events.offer(parsed);
                } catch (Exception e) {
                    events.offer(Map.of("type", "TEST_JSON_PARSE_ERROR", "raw", message));
                }
            }
            return WebSocket.Listener.super.onText(webSocket, data, last);
        }
    }
}
