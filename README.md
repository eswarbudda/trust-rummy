# Trust Rummy

Real-time multiplayer Rummy platform. Monorepo with a Java Spring Boot backend and a Flutter frontend.

```
┌────────────────────────────────────────────────────────┐
│                   FLUTTER FRONTEND                     │
│   ┌────────────────────────┐  ┌────────────────────┐   │
│   │   Sleek UI (Material)  │  │ WebSocket Service  │   │
│   └───────────▲────────────┘  └─────────▲──────────┘   │
└───────────────┼─────────────────────────┼──────────────┘
                │ REST API (HTTPS)        │ Real-time Loop (WSS)
                │                         │
┌───────────────▼─────────────────────────▼──────────────┐
│                  JAVA SPRING BOOT SERVER               │
│   ┌────────────────────────┐  ┌────────────────────┐   │
│   │ REST controllers       │  │ WebSocket Handlers │   │
│   │ Auth / Wallet / Rooms  │  │ GameState Engine   │   │
│   └───────────▲────────────┘  └─────────▲──────────┘   │
└───────────────┼─────────────────────────┼──────────────┘
                │ JPA / Hibernate         │ In-Memory Sync
                └───────────────┬─────────┘
                        ┌───────▼────────┐
                        │   POSTGRESQL   │
                        └────────────────┘
```

## Repository layout

- `/backend` — Spring Boot 3.x (Java 17, Maven) REST + WebSocket server.
- `/frontend` — Flutter client (Material 3 UI + WebSocket service).

## Backend — quick start

```bash
cd backend

# 1. Start PostgreSQL locally (or point spring.datasource.* at your own instance)
#    createdb trust_rummy

# 2. Run the server
mvn spring-boot:run
```

The server starts on `http://localhost:8080`.

Key endpoints:

| Method | Path                  | Purpose                              |
|--------|-----------------------|---------------------------------------|
| POST   | `/api/auth/register`  | Create a user, returns a JWT          |
| POST   | `/api/auth/login`     | Authenticate, returns a JWT           |
| GET    | `/api/wallet/balance` | Authenticated wallet balance lookup   |
| POST   | `/api/rooms`          | Create a game room                    |
| GET    | `/api/rooms`          | List open (`WAITING`) rooms           |
| WS     | `/ws/telemetry?token=<jwt>` | Real-time connectivity smoke test |
| WS     | `/ws/game/{roomCode}?token=<jwt>` | Live gameplay channel (stub) |

Configuration lives in `backend/src/main/resources/application.properties`. Override the JWT secret and DB
credentials via environment variables (`JWT_SECRET`, `SPRING_DATASOURCE_*`) in real deployments — never commit
production secrets.

## Frontend — quick start

```bash
cd frontend

# First time only: Flutter needs to generate platform folders (android/ios/web bindings)
flutter create . --platforms=web,android,ios --org com.trustrummy

flutter pub get
flutter run -d chrome
```

This launches the **Live Telemetry** screen: tap **Connect** to register a disposable test user against the
backend, receive a JWT, and open a JWT-authenticated WebSocket to `/ws/telemetry` — the log panel and latency
readout confirm the full REST → JWT → WSS loop is wired correctly end-to-end.

By default the app targets `localhost:8080`. Override with:

```bash
flutter run -d chrome --dart-define=API_HOST=192.168.1.10:8080
```

### Background images (lobby + game board)

Bundled defaults live in `frontend/assets/images/`. Paths, enable flags, and scrim strength
are configurable via `--dart-define` (see `lib/config/ui_config.dart`):

```bash
flutter run --dart-define=LOBBY_BG_ASSET=assets/images/lobby_bg.png \
  --dart-define=LOBBY_SCRIM_PERCENT=65 \
  --dart-define=BOARD_BG_ASSET=assets/images/board_bg.png \
  --dart-define=BOARD_SCRIM_PERCENT=42

# Or remote images (falls back to asset on load failure):
flutter run --dart-define=LOBBY_BG_URL=https://cdn.example.com/lobby.jpg \
  --dart-define=BOARD_BG_URL=https://cdn.example.com/board.jpg

# Disable and use solid/gradient fallbacks:
flutter run --dart-define=LOBBY_BG_ENABLED=false --dart-define=BOARD_BG_ENABLED=false
```

## Security model (Phase 1)

- Stateless JWT auth — no HTTP sessions (`SessionCreationPolicy.STATELESS`).
- WebSocket upgrade handshakes are authenticated via `JwtHandshakeInterceptor` *before* the socket is accepted.
- CORS is locked to explicit localhost/dev origins (`cors.allowed-origins` in `application.properties`).
- WebSocket transport enforces payload/session limits via `ServletServerContainerFactoryBean`.
- Live gameplay/room state is held in a thread-safe in-memory `ConcurrentHashMap` (`GameStateService`) — the hot
  path never touches PostgreSQL directly. Durable persistence (audit log, results) happens asynchronously via JPA.
