# Player Identity & Action Flow

Trust-Rummy uses **raw WebSockets** (not STOMP). The durable identity is the DB `User.id` (`Long`). Live play keys everything by that `userId`. Lobby seating is a separate DB `RoomPlayer` row; connecting a socket alone does not seat you.

---

## 1. Player identity model

### What represents a "player"?

There are **three related layers**, not one class:

| Layer | Class | Role |
|--------|--------|------|
| Account | `User` (JPA) | Auth identity: `id`, `username`, … |
| Lobby seat | `RoomPlayer` (JPA) | Association of user ↔ room + `seatNumber` + lobby `PlayerStatus` |
| Live match | `PlayerScorecard` + maps keyed by `Long userId` | In-memory match/deal state |

**Account (`User`):**

```23:37:backend/src/main/java/com/trustrummy/backend/entity/User.java
public class User {

 @Id
 @GeneratedValue(strategy = GenerationType.IDENTITY)
 private Long id;

 @Column(nullable = false, length = 32)
 private String username;
 // ...
```

**Lobby seat (`RoomPlayer`):** unique `(room_id, user_id)`, seat, status:

```12:45:backend/src/main/java/com/trustrummy/backend/entity/RoomPlayer.java
@Entity
@Table(name = "room_players", uniqueConstraints = {
 @UniqueConstraint(columnNames = {"room_id", "user_id"})
})
public class RoomPlayer {

 @Id
 @GeneratedValue(strategy = GenerationType.IDENTITY)
 private Long id;
 // ... GameRoom gameRoom, User user ...
 @Column(name = "seat_number")
 private Integer seatNumber;
 // ... PlayerStatus status, Integer score ...
```

**Live match identity** is not the stub `game.model.Player` (that class exists but is **never imported/used** on the hot path). The engine uses:

- `MatchState.seatOrder: List<Long>` — stable userId order for the match
- `MatchState.scorecards: Map<Long, PlayerScorecard>` — username, seat, cumulative score, match status
- `Deal.hands / roundStatus / turnOrder` — all keyed by `Long userId`

```38:42:backend/src/main/java/com/trustrummy/backend/game/state/MatchState.java
 /** Stable seat order for the whole match (does not change between deals). */
 private final List<Long> seatOrder = new CopyOnWriteArrayList<>();

 /** userId -> cumulative scorecard, persists across every deal in the match. */
 private final Map<Long, PlayerScorecard> scorecards = new ConcurrentHashMap<>();
```

```20:32:backend/src/main/java/com/trustrummy/backend/game/state/PlayerScorecard.java
public class PlayerScorecard {

 private Long userId;
 private String username;
 private Integer seatNumber;
 // cumulativeScore, matchStatus (ACTIVE / ELIMINATED / WINNER)
```

`game.model.Player` is an older plain holder (`userId`, `username`, `seatNumber`, `hand`, …) and is unused by the engine today.

### Unique ID across a game session

Canonical ID: **`User.id` (`Long`)**, not WebSocket session id and not JWT subject alone.

JWT subject is the **username** string:

```53:68:backend/src/main/java/com/trustrummy/backend/security/JwtTokenUtil.java
 public String generateToken(Map<String, Object> extraClaims, UserDetails userDetails) {
 // ...
 return Jwts.builder()
 .claims(extraClaims)
 .subject(userDetails.getUsername())
 // ...
 }

 public String extractUsername(String token) {
 return extractClaim(token, Claims::getSubject);
 }
```

At match start, seated `RoomPlayer` rows are copied into `MatchState` keyed by that DB id:

```165:175:backend/src/main/java/com/trustrummy/backend/service/RummyEngineService.java
 for (RoomPlayer rp : seated) {
 Long userId = rp.getUser().getId();
 match.getSeatOrder().add(userId);
 match.getScorecards().put(userId, PlayerScorecard.builder()
 .userId(userId)
 .username(rp.getUser().getUsername())
 .seatNumber(rp.getSeatNumber())
 .cumulativeScore(0)
 .matchStatus(MatchPlayerStatus.ACTIVE)
 .build());
 }
```

### Auth / connection → in-game player

**REST (lobby):**
`JwtAuthenticationFilter` sets Spring Security principal from Bearer JWT → `@AuthenticationPrincipal UserDetails` → `principal.getUsername()` → `RoomService` loads `User` by username.

```51:68:backend/src/main/java/com/trustrummy/backend/security/JwtAuthenticationFilter.java
 if (authHeader == null || !authHeader.startsWith(BEARER_PREFIX)) {
 filterChain.doFilter(request, response);
 return;
 }
 String token = authHeader.substring(BEARER_PREFIX.length());
 // ... extractUsername → loadUserByUsername → SecurityContext ...
```

`/ws/**` is `permitAll` in Spring Security; real WS auth is the handshake interceptor:

```53:58:backend/src/main/java/com/trustrummy/backend/config/SecurityConfig.java
 .authorizeHttpRequests(auth -> auth
 .requestMatchers("/api/v1/auth/**").permitAll()
 .requestMatchers("/actuator/health").permitAll()
 .requestMatchers("/ws/**").permitAll()
 .anyRequest().authenticated()
```

**WebSocket (gameplay):** raw endpoint `/ws/game/{roomCode}` with JWT on handshake:

```44:46:backend/src/main/java/com/trustrummy/backend/config/WebSocketConfig.java
 WebSocketHandlerRegistration gameRegistration = registry
 .addHandler(gameWebSocketHandler, "/ws/game/{roomCode}")
 .addInterceptors(jwtHandshakeInterceptor());
```

Handshake validates JWT (`?token=` or `Authorization: Bearer`) and stores **username** (not userId) on session attributes:

```40:57:backend/src/main/java/com/trustrummy/backend/security/JwtHandshakeInterceptor.java
 String token = extractToken(request);
 // ... reject if missing/invalid ...
 String username = jwtTokenUtil.extractUsername(token);
 attributes.put("username", username);
 attributes.put("token", token);
 return true;
```

`GameWebSocketHandler` resolves username → `User.id`, stores `userId` + `roomCode` on the session, and registers the socket:

```49:67:backend/src/main/java/com/trustrummy/backend/websocket/GameWebSocketHandler.java
 public void afterConnectionEstablished(WebSocketSession session) {
 String roomCode = extractRoomCode(session);
 String username = (String) session.getAttributes().getOrDefault("username", null);

 Optional<User> user = username != null ? userRepository.findByUsername(username) : Optional.empty();
 // ... reject if unknown ...
 Long userId = user.get().getId();
 session.getAttributes().put(USER_ID_ATTR, userId);
 session.getAttributes().put(ROOM_CODE_ATTR, roomCode);

 broadcastService.register(roomCode, userId, session);
 broadcastService.sendTo(roomCode, userId, rummyEngineService.buildSnapshotEventFor(roomCode, userId));
 }
```

Session registry (connection identity, not game identity):

```31:49:backend/src/main/java/com/trustrummy/backend/game/ws/GameBroadcastService.java
 /** roomCode -> (userId -> live session). */
 private final Map<String, Map<Long, WebSocketSession>> roomSessions = new ConcurrentHashMap<>();
 // ...
 public void register(String roomCode, Long userId, WebSocketSession session) {
 roomSessions.computeIfAbsent(roomCode, r -> new ConcurrentHashMap<>()).put(userId, session);
 // clears disconnect timestamp on reconnect
```

**Critical security detail:** inbound JSON (`GameActionMessage`) has **no `userId` field**. The acting player is always the handshake-derived session `userId`. Clients cannot spoof identity in the action payload.

```17:21:backend/src/main/java/com/trustrummy/backend/game/ws/GameActionMessage.java
public class GameActionMessage {
 private ActionType type;
 private DrawSource source;
 private String cardCode;
}
```

### Association with Match / Room / Table

1. **Create room (REST)** → host auto-seated at seat `0` as `RoomPlayer`.
2. **Join (REST)** → next free seat.
3. **Connect WS** → channel only; does **not** create a seat (documented in `RoomService` and `RULES_ENGINE.md`).
4. **`START_MATCH` (WS)** → loads non-`LEFT` `RoomPlayer`s into `MatchState`.

```81:87:backend/src/main/java/com/trustrummy/backend/service/RoomService.java
 /**
 * Seats a user into an existing room by code. This is the piece that was
 * previously missing: connecting the game WebSocket only registers a
 * live session for broadcasts, it does NOT create a {@link RoomPlayer}
 * row — without calling this first, {@code RummyEngineService} never
 * sees the second/third/... player as "seated" ...
```

Durable post-match record: `GameSession` (room + winner + status), plus `GameMoveLog` rows and `RoomPlayer.score`.

There is **no spectator model**. Anyone with a valid JWT can open `/ws/game/{roomCode}` and receive personalized broadcasts (hands redacted for others). They are not in `seatOrder` unless seated before `START_MATCH`, so they cannot pass the turn check for draw/discard/etc.

---

## 2. Player actions flow

### Where actions enter

**Only WebSocket.** No REST endpoints for draw/discard/declare/drop.

```71:93:backend/src/main/java/com/trustrummy/backend/websocket/GameWebSocketHandler.java
 protected void handleTextMessage(WebSocketSession session, TextMessage message) {
 String roomCode = (String) session.getAttributes().get(ROOM_CODE_ATTR);
 Long userId = (Long) session.getAttributes().get(USER_ID_ATTR);
 // ...
 GameActionMessage action = objectMapper.readValue(message.getPayload(), GameActionMessage.class);
 rummyEngineService.handleAction(roomCode, userId, action);
```

Action types: `START_MATCH`, `DRAW_CARD`, `DISCARD_CARD`, `DECLARE`, `DROP` (`ActionType`).

Lobby seating/ready stays on REST (`RoomController`).

### Authorization / turn validation

**Identity:** session `userId` from JWT (above).

**`START_MATCH`:** host-only (`GameRoom.createdBy`), match `WAITING`, ≥2 seated players:

```130:150:backend/src/main/java/com/trustrummy/backend/service/RummyEngineService.java
 private void startMatch(MatchState match, Long requesterUserId) {
 // ...
 if (room.getCreatedBy() == null || !room.getCreatedBy().getId().equals(requesterUserId)) {
 sendError(match.getRoomCode(), requesterUserId, "Only the host can start the match");
 return;
 }
 // ... Need at least 2 seated players ...
```

**All other actions:** under `MatchState.lock`, require active deal, then **strict turn ownership**:

```78:112:backend/src/main/java/com/trustrummy/backend/service/RummyEngineService.java
 public void handleAction(String roomCode, Long userId, GameActionMessage action) {
 MatchState match = gameStateService.getOrCreate(roomCode);
 // START_MATCH branch ...
 match.getLock().lock();
 try {
 Deal deal = match.getCurrentDeal();
 if (match.getStatus() != MatchStatus.IN_PROGRESS || deal == null || deal.getStatus() != DealStatus.IN_PROGRESS) {
 sendError(roomCode, userId, "No active deal in progress");
 return;
 }
 if (!userId.equals(deal.currentTurnUserId())) {
 sendError(roomCode, userId, "It is not your turn");
 return;
 }
 switch (action.getType()) { /* DRAW / DISCARD / DECLARE / DROP */ }
 } finally {
 match.getLock().unlock();
 }
 }
```

Whose turn:

```62:67:backend/src/main/java/com/trustrummy/backend/game/state/Deal.java
 public Long currentTurnUserId() {
 if (turnOrder.isEmpty()) {
 return null;
 }
 return turnOrder.get(currentTurnIndex);
 }
```

Phase checks (after turn check):

| Action | Required phase | Extra checks |
|--------|----------------|---------------|
| `DRAW_CARD` | `AWAITING_DRAW` | `source` CLOSED/OPEN |
| `DISCARD_CARD` / `DECLARE` | `AWAITING_DISCARD` | card must be in **that** user's hand |
| `DROP` | `AWAITING_DRAW` | before drawing |

Hand ownership is enforced by mutating `deal.getHands().get(userId)` only (e.g. discard removes by code from that list).

### Full call path

```
Client JSON → GameWebSocketHandler.handleTextMessage
 → RummyEngineService.handleAction (ReentrantLock)
 → handleDraw / handleDiscard / handleDeclare / handleDrop
 → mutate Deal / MatchState
 → HandValidator (declare) / ScoreCalculator (drop/end)
 → GamePersistenceService.recordMove (@Async, fire-and-forget)
 → GameBroadcastService.broadcastPersonalized / broadcast / sendTo
```

Example draw path:

```373:404:backend/src/main/java/com/trustrummy/backend/service/RummyEngineService.java
 private void handleDraw(...) {
 // phase + source checks ...
 deal.getHands().computeIfAbsent(userId, k -> new ArrayList<>()).add(drawn);
 deal.setTurnPhase(TurnPhase.AWAITING_DISCARD);
 persistenceService.recordMove(...);
 broadcastDealState(match, deal, EventType.CARD_DRAWN);
 }
```

Discard advances turn via `advanceAfterDiscard` → `deal.advanceTurn()` → `TURN_STATE` + reschedule timeout.

`GameStateService` holds `ConcurrentHashMap<roomCode, MatchState>` — hot path stays in memory; DB is async audit.

### Persistence & async

```43:72:backend/src/main/java/com/trustrummy/backend/service/GamePersistenceService.java
 @Async("gamePersistenceExecutor")
 @Transactional
 public void recordMatchStart(String roomCode) { /* room IN_PROGRESS + GameSession ACTIVE */ }

 @Async("gamePersistenceExecutor")
 @Transactional
 public void recordMove(String roomCode, Long userId, MoveType moveType, String moveDataJson, long sequenceNo) { ... }

 @Async("gamePersistenceExecutor")
 @Transactional
 public void recordMatchEnd(...) { /* COMPLETED vs ABORTED, RoomPlayer.score */ }
```

`AsyncConfig` forces a **single-thread** executor so start → moves → end stay FIFO and don't race:

```29:38:backend/src/main/java/com/trustrummy/backend/config/AsyncConfig.java
 public TaskExecutor gamePersistenceExecutor() {
 ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
 executor.setCorePoolSize(1);
 executor.setMaxPoolSize(1);
 // ...
```

### Broadcast / hidden info

Deal events use **per-recipient** payloads:

```683:724:backend/src/main/java/com/trustrummy/backend/service/RummyEngineService.java
 private void broadcastDealState(...) {
 broadcastService.broadcastPersonalized(match.getRoomCode(), viewerId -> buildDealEvent(...));
 }
 // buildPlayerViews: every seat gets handSize; hand[] only if userId.equals(viewerId)
```

Same-shape events for all (`CARD_DRAWN`, `TURN_STATE`, …) but each socket gets a different `players[].hand`. Errors go only to the actor via `sendTo`. Room-wide events (`SCORE_UPDATE`, `DECLARE_RESULT`, `MATCH_ENDED`, `PLAYER_ELIMINATED`) use identical `broadcast`.

Not topic/queue STOMP routing — direct `WebSocketSession.sendMessage` to registered sessions.

### Auto-play & disconnect (not client actions)

- **Turn timeout:** `TurnManager` schedules `onTurnTimeout` → auto closed-deck draw + auto-discard (or drop if empty).
- **Disconnect:** `unregister` stamps `disconnectedSince`; `RoomLifecycleService` (default every 60s, 90s grace) calls `forfeitDisconnectedPlayer` (forced drop, even off-turn).

---

## 3. Supporting files (map)

| Concern | Path |
|---------|------|
| Design / contract | `RULES_ENGINE.md` |
| WS wiring | `backend/.../config/WebSocketConfig.java` |
| JWT handshake | `backend/.../security/JwtHandshakeInterceptor.java` |
| JWT REST filter | `backend/.../security/JwtAuthenticationFilter.java` |
| Game WS handler | `backend/.../websocket/GameWebSocketHandler.java` |
| Session registry + broadcast | `backend/.../game/ws/GameBroadcastService.java` |
| Engine | `backend/.../service/RummyEngineService.java` |
| In-memory registry | `backend/.../service/GameStateService.java` |
| Async persistence | `backend/.../service/GamePersistenceService.java`, `config/AsyncConfig.java` |
| Lobby seat lifecycle | `backend/.../service/RoomService.java`, `controller/RoomController.java` |
| Disconnect/stale lobby reaper | `backend/.../service/RoomLifecycleService.java` |
| Turn timer | `backend/.../game/engine/TurnManager.java` |
| Match cleanup regression | `backend/.../test/.../MatchLifecycleCleanupIntegrationTest.java` |

---

## 4. Notable design details & gaps

1. **WS ≠ seat.** You must `POST /api/v1/rooms/{code}/join` before you count for `START_MATCH`. Socket alone only gets broadcasts.
2. **No spectator distinction.** Extra authenticated users can watch a room's WS; they see redacted hands. No explicit spectator role.
3. **Unused stubs:** `game.model.Player` and likely `game.model.GameRoom` are phase-1 leftovers; live state is `MatchState` / `Deal` / `PlayerScorecard`.
4. **Reconnect:** same `userId` overwrites the previous session in `roomSessions`; reconnect clears disconnect grace. Brief double-connect races replace the old socket.
5. **Concurrency:** per-room `ReentrantLock` serializes actions; timers/reaper also take that lock. Persistence is off-thread and ordered per `AsyncConfig`.
6. **Match end eviction:** `finishMatch` removes `MatchState` from memory after `MATCH_ENDED` (what the lifecycle integration test asserts).
7. **No client-supplied player id on actions** — identity is connection-bound; turn check is `userId.equals(deal.currentTurnUserId())`.
