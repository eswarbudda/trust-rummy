package com.trustrummy.backend.security;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.http.server.ServletServerHttpRequest;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.server.HandshakeInterceptor;

import java.util.List;
import java.util.Map;

/**
 * Rule 2: Intercepts the initial WebSocket HTTP upgrade handshake and
 * validates the JWT BEFORE the socket connection is ever established.
 * <p>
 * The token may be supplied either as a query parameter
 * ({@code ws://host/ws/telemetry?token=...}) since browsers/Flutter's
 * web-socket client cannot set custom headers during the upgrade, or via
 * a Sec-WebSocket-Protocol / Authorization header for native clients.
 */
@Slf4j
@RequiredArgsConstructor
public class JwtHandshakeInterceptor implements HandshakeInterceptor {

    private static final String TOKEN_QUERY_PARAM = "token";
    private static final String AUTH_HEADER = "Authorization";
    private static final String BEARER_PREFIX = "Bearer ";

    private final JwtTokenUtil jwtTokenUtil;

    @Override
    public boolean beforeHandshake(
            ServerHttpRequest request,
            ServerHttpResponse response,
            WebSocketHandler wsHandler,
            Map<String, Object> attributes
    ) {
        String token = extractToken(request);

        if (token == null || token.isBlank()) {
            log.warn("WebSocket handshake rejected: missing JWT token");
            response.setStatusCode(org.springframework.http.HttpStatus.UNAUTHORIZED);
            return false;
        }

        if (!jwtTokenUtil.isTokenValid(token)) {
            log.warn("WebSocket handshake rejected: invalid or expired JWT token");
            response.setStatusCode(org.springframework.http.HttpStatus.UNAUTHORIZED);
            return false;
        }

        String username = jwtTokenUtil.extractUsername(token);
        attributes.put("username", username);
        attributes.put("token", token);
        return true;
    }

    @Override
    public void afterHandshake(
            ServerHttpRequest request,
            ServerHttpResponse response,
            WebSocketHandler wsHandler,
            Exception exception
    ) {
        if (exception != null) {
            log.error("Error during WebSocket handshake", exception);
        }
    }

    private String extractToken(ServerHttpRequest request) {
        if (request instanceof ServletServerHttpRequest servletRequest) {
            String queryToken = servletRequest.getServletRequest().getParameter(TOKEN_QUERY_PARAM);
            if (queryToken != null && !queryToken.isBlank()) {
                return queryToken;
            }
        }

        List<String> authHeaders = request.getHeaders().get(AUTH_HEADER);
        if (authHeaders != null && !authHeaders.isEmpty()) {
            String header = authHeaders.get(0);
            if (header.startsWith(BEARER_PREFIX)) {
                return header.substring(BEARER_PREFIX.length());
            }
        }

        return null;
    }
}
