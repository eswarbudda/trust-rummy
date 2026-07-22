package com.trustrummy.backend;

import com.trustrummy.backend.dto.ChangePasswordRequest;
import com.trustrummy.backend.repository.RefreshTokenRepository;
import com.trustrummy.backend.repository.UserRepository;
import com.trustrummy.backend.security.RefreshTokenHasher;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * End-to-end auth MVP: register, login, refresh rotation, reuse revoke-all,
 * logout, change-password session kill.
 */
@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = "auth.rate-limit.max-attempts=1000"
)
class AuthFlowIntegrationTest extends AbstractGameIntegrationTest {

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Test
    void registerLoginRefreshLogoutAndPasswordChangeRevokeSessions() {
        long unique = System.nanoTime();
        String username = "authflow_" + unique;
        String password = "Password123!";

        Map<String, Object> regBody = postJson("/api/v1/auth/register", registerBody(username, password));
        assertThat(regBody.get("token")).isNotNull();
        assertThat(regBody.get("refreshToken")).isNotNull();
        assertThat(((Number) regBody.get("expiresInMs")).longValue()).isEqualTo(900_000L);

        String refresh1 = (String) regBody.get("refreshToken");
        assertThat(refreshTokenRepository.findByToken(RefreshTokenHasher.sha256Hex(refresh1))).isPresent();
        assertThat(refreshTokenRepository.findByToken(refresh1)).isEmpty();

        Map<String, Object> loginBody = postJson("/api/v1/auth/login", loginBody(username, password));
        String refresh2 = (String) loginBody.get("refreshToken");

        Map<String, Object> rotated = postJson("/api/v1/auth/refresh", Map.of("refreshToken", refresh2));
        String refresh3 = (String) rotated.get("refreshToken");
        assertThat(refresh3).isNotEqualTo(refresh2);

        ResponseEntity<String> reuseRes = postJsonRaw("/api/v1/auth/refresh", Map.of("refreshToken", refresh2));
        assertThat(reuseRes.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        ResponseEntity<String> killedRes = postJsonRaw("/api/v1/auth/refresh", Map.of("refreshToken", refresh3));
        assertThat(killedRes.getStatusCode()).isIn(HttpStatus.CONFLICT, HttpStatus.BAD_REQUEST);

        Map<String, Object> login2 = postJson("/api/v1/auth/login", loginBody(username, password));
        String refreshLogout = (String) login2.get("refreshToken");

        ResponseEntity<String> logoutRes = postJsonRaw("/api/v1/auth/logout", Map.of("refreshToken", refreshLogout));
        assertThat(logoutRes.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        ResponseEntity<String> afterLogoutRefresh =
                postJsonRaw("/api/v1/auth/refresh", Map.of("refreshToken", refreshLogout));
        assertThat(afterLogoutRefresh.getStatusCode()).isIn(HttpStatus.CONFLICT, HttpStatus.BAD_REQUEST);

        Map<String, Object> login3 = postJson("/api/v1/auth/login", loginBody(username, password));
        String access = (String) login3.get("token");
        String refreshBeforePw = (String) login3.get("refreshToken");

        ChangePasswordRequest pw = new ChangePasswordRequest();
        pw.setCurrentPassword(password);
        pw.setNewPassword("NewPassword123!");
        HttpHeaders headers = authHeaders(access);
        headers.setContentType(MediaType.APPLICATION_JSON);
        ResponseEntity<String> pwRes = rest.exchange(
                baseUrl("/api/v1/users/me/password"),
                HttpMethod.PUT,
                new HttpEntity<>(pw, headers),
                String.class);
        assertThat(pwRes.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        ResponseEntity<String> afterPwRefresh =
                postJsonRaw("/api/v1/auth/refresh", Map.of("refreshToken", refreshBeforePw));
        assertThat(afterPwRefresh.getStatusCode()).isIn(HttpStatus.CONFLICT, HttpStatus.BAD_REQUEST);

        // Prefer DB assertion: JDK HttpURLConnection + 401 WWW-Authenticate is flaky in TestRestTemplate.
        var user = userRepository.findByUsername(username).orElseThrow();
        assertThat(passwordEncoder.matches("NewPassword123!", user.getPasswordHash())).isTrue();
        assertThat(passwordEncoder.matches(password, user.getPasswordHash())).isFalse();
    }

    private Map<String, Object> registerBody(String username, String password) {
        return Map.of(
                "username", username,
                "email", username + "@example.com",
                "password", password,
                "displayName", username);
    }

    private Map<String, Object> loginBody(String username, String password) {
        return Map.of("username", username, "password", password);
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> postJson(String path, Object body) {
        ResponseEntity<Map> response = rest.exchange(
                baseUrl(path),
                HttpMethod.POST,
                jsonEntity(body),
                Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return response.getBody();
    }

    private ResponseEntity<String> postJsonRaw(String path, Object body) {
        return rest.exchange(baseUrl(path), HttpMethod.POST, jsonEntity(body), String.class);
    }

    private HttpEntity<Object> jsonEntity(Object body) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        return new HttpEntity<>(body, headers);
    }
}
